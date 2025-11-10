import CanIClimbKit
import CustomDump
import Dependencies
import Foundation
import Logging
import SQLiteData
import SharingOperation
import SnapshotTesting
import Synchronization
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("Mountain+ClimbReadiness+FoundationModelsGenerator tests")
  struct MountainClimbReadinessFoundationModelsTests {
    @Test("Generation, Active Person")
    func generationActivePerson() async throws {
      try await self.generate(
        snapshotName: "generationActivePerson.json",
        loggerLabel: "generation.test.active.person",
        humanity: .active20s,
        vo2MaxSamples: .goodVO2Max,
        stepCounterSamples: .goodStepCounter,
        distanceWalkingRunningSamples: .goodDistanceWalkingRunning
      )
    }

    @Test("Generation, Inactive Person")
    func generationInactivePerson() async throws {
      try await self.generate(
        snapshotName: "generationInactivePerson.json",
        loggerLabel: "generation.test.inactive.person",
        humanity: .inactive20s,
        vo2MaxSamples: .badVO2Max,
        stepCounterSamples: .badStepCounter,
        distanceWalkingRunningSamples: .badDistanceWalkingRunning
      )
    }

    private func generate(
      snapshotName: String,
      loggerLabel: String,
      humanity: UserHumanityRecord,
      vo2MaxSamples: NumericHealthSamples,
      stepCounterSamples: NumericHealthSamples,
      distanceWalkingRunningSamples: NumericHealthSamples
    ) async throws {
      let toolLogHandler = ToolLogHandler()
      var logger = Logger(label: loggerLabel) { label in
        MultiplexLogHandler([toolLogHandler, StreamLogHandler.standardOutput(label: label)])
      }
      logger.handler.logLevel = .debug
      let mountain = Mountain.freelPeak

      try await withDependencies {
        let location = LocationReading.mock()

        let userLocation = MockUserLocation()
        userLocation.currentReading = .success(location)
        $0[UserLocationKey.self] = userLocation

        let weather = WeatherReading.MockCurrentReader()
        weather.results[location.coordinate] = .success(.mock(location: location))
        weather.results[mountain.location.coordinate] = .success(.freelPeak)
        $0[WeatherReading.CurrentReaderKey.self] = weather
      } operation: {
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.defaultOperationClient) var client

        try await database.write { try humanity.save(in: $0) }

        let generator = MountainClimbReadiness.FoundationModelsGenerator(
          database: database,
          client: client,
          vo2MaxLoader: NumericHealthSamples.SucceedingLoader(
            kind: .vo2Max,
            response: vo2MaxSamples
          ),
          stepCounterLoader: NumericHealthSamples.SucceedingLoader(
            kind: .stepCount,
            response: stepCounterSamples
          ),
          distanceWalkingRunningLoader: NumericHealthSamples.SucceedingLoader(
            kind: .distanceWalkingRunningMeters,
            response: distanceWalkingRunningSamples
          )
        )

        let generation = try await withCurrentLogger(logger) { @Sendable in
          let segments = generator.readiness(for: mountain)
          var readiness: MountainClimbReadiness?
          for try await segment in segments {
            guard case .full(let r) = segment else { continue }
            readiness = r
          }
          return Generation(readiness: readiness, messages: toolLogHandler.toolMessages)
        }
        withKnownIssue {
          assertSnapshot(of: generation, as: .json, record: true, testName: snapshotName)
        }
      }
    }
  }

  private struct Generation: Sendable, Codable {
    var readiness: MountainClimbReadiness?
    var messages: [ToolMessage]
  }
}

// MARK: - ToolLogHandler

private final class ToolLogHandler: LogHandler {
  private struct State {
    var metadata = Logger.Metadata()
    var logLevel = Logger.Level.debug
    var messages = [ToolMessage]()
  }

  private let state = Mutex(State())

  subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
    get { self.metadata[key] }
    set { self.metadata[key] = newValue }
  }

  var metadata: Logger.Metadata {
    get { self.state.withLock { $0.metadata } }
    set { self.state.withLock { $0.metadata = newValue } }
  }

  var logLevel: Logger.Level {
    get { self.state.withLock { $0.logLevel } }
    set { self.state.withLock { $0.logLevel = newValue } }
  }

  var toolMessages: [ToolMessage] {
    self.state.withLock { $0.messages }
  }

  func log(
    level: Logger.Level,
    message: Logger.Message,
    metadata: Logger.Metadata?,
    source: String,
    file: String,
    function: String,
    line: UInt
  ) {
    self.state.withLock {
      $0.messages.append(
        ToolMessage(
          content: message.description,
          metadata: metadata?.mapValues(\.codableRepresentation)
        )
      )
    }
  }
}

private struct ToolMessage: Hashable, Sendable, Codable {
  var content: String
  var metadata: [String: Logger.MetadataValue.CodableRepresentation]?
}

// MARK: - Mock Data

extension UserHumanityRecord {
  fileprivate static let active20s = Self(
    height: .imperial(HumanHeight.Imperial(feet: 5, inches: 10)),
    weight: Measurement(value: 165, unit: .pounds),
    ageRange: .in20s,
    gender: .male,
    activityLevel: .active,
    workoutFrequency: .everyDay
  )

  fileprivate static let inactive20s = Self(
    height: .imperial(HumanHeight.Imperial(feet: 5, inches: 10)),
    weight: Measurement(value: 204, unit: .pounds),
    ageRange: .in20s,
    gender: .male,
    activityLevel: .sedentary,
    workoutFrequency: .noDays
  )
}

extension NumericHealthSamples {
  fileprivate static let goodVO2Max = Self(
    kind: .vo2Max,
    elements: [Element(timestamp: .now, value: 55.2)]
  )

  fileprivate static let badVO2Max = Self(
    kind: .vo2Max,
    elements: [Element(timestamp: .now, value: 33.4)]
  )

  fileprivate static let goodStepCounter = Self(
    kind: .stepCount,
    elements: [
      Element(timestamp: .now, value: 12_021),
      Element(timestamp: .now - oneDay, value: 15_253),
      Element(timestamp: .now - oneDay * 2, value: 11_928),
      Element(timestamp: .now - oneDay * 3, value: 10_102),
      Element(timestamp: .now - oneDay * 4, value: 16_234),
      Element(timestamp: .now - oneDay * 5, value: 12_391),
      Element(timestamp: .now - oneDay * 6, value: 13_311)
    ]
  )

  fileprivate static let badStepCounter = Self(
    kind: .stepCount,
    elements: [
      Element(timestamp: .now, value: 982),
      Element(timestamp: .now - oneDay, value: 1232),
      Element(timestamp: .now - oneDay * 2, value: 1041),
      Element(timestamp: .now - oneDay * 3, value: 232),
      Element(timestamp: .now - oneDay * 4, value: 678),
      Element(timestamp: .now - oneDay * 5, value: 1109),
      Element(timestamp: .now - oneDay * 6, value: 2134)
    ]
  )

  fileprivate static let goodDistanceWalkingRunning = Self(
    kind: .distanceWalkingRunningMeters,
    elements: [
      Element(timestamp: .now, value: oneMile * 3.3894),
      Element(timestamp: .now - oneDay, value: oneMile * 4.92873),
      Element(timestamp: .now - oneDay * 2, value: oneMile * 3.0289),
      Element(timestamp: .now - oneDay * 3, value: oneMile * 2.8393),
      Element(timestamp: .now - oneDay * 4, value: oneMile * 5.1092),
      Element(timestamp: .now - oneDay * 5, value: oneMile * 3.4982),
      Element(timestamp: .now - oneDay * 6, value: oneMile * 3.6283)
    ]
  )

  fileprivate static let badDistanceWalkingRunning = Self(
    kind: .distanceWalkingRunningMeters,
    elements: [
      Element(timestamp: .now, value: oneMile * 0.82873),
      Element(timestamp: .now - oneDay, value: oneMile * 1.1293),
      Element(timestamp: .now - oneDay * 2, value: oneMile * 1.0893),
      Element(timestamp: .now - oneDay * 3, value: oneMile * 0.2933),
      Element(timestamp: .now - oneDay * 4, value: oneMile * 0.6287),
      Element(timestamp: .now - oneDay * 5, value: oneMile * 1.0782),
      Element(timestamp: .now - oneDay * 6, value: oneMile * 1.5038)
    ]
  )
}

private let oneDay = TimeInterval(24 * 60 * 60)
private let oneMile = 1609.34
