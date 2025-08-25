import Dependencies
import GRDB
import HealthKit
import Operation
import StructuredQueriesGRDB
import SwiftUINavigation

// MARK: - HealthPermissions

public final class HealthPermissions: Sendable {
  private let database: any DatabaseWriter
  private let requester: any HealthPermissions.Requester

  public init(
    database: any DatabaseWriter,
    requester: any HealthPermissions.Requester
  ) {
    self.database = database
    self.requester = requester
  }

  public func request() async throws {
    try await self.requester.requestCanIClimbPermissions()
    try await self.database.write { db in
      try LocalInternalMetricsRecord.update(in: db) { $0.hasConnectedHealthKit = true }
    }
  }
}

// MARK: - DependencyKey

extension HealthPermissions: DependencyKey {
  public static var liveValue: HealthPermissions {
    @Dependency(\.defaultDatabase) var database
    return HealthPermissions(database: database, requester: HKHealthStore.canIClimb)
  }
}

// MARK: - Requester

extension HealthPermissions {
  public protocol Requester: Sendable {
    func requestCanIClimbPermissions() async throws
  }
}

extension HKHealthStore: HealthPermissions.Requester {
  public func requestCanIClimbPermissions() async throws {
    try await self.requestAuthorization(
      toShare: [],
      read: [
        .activitySummaryType(),
        .workoutType(),
        .stateOfMindType(),
        .quantityType(forIdentifier: .stepCount)!,
        .quantityType(forIdentifier: .vo2Max)!,
        .quantityType(forIdentifier: .activeEnergyBurned)!,
        .quantityType(forIdentifier: .heartRate)!,
        .quantityType(forIdentifier: .distanceWalkingRunning)!
      ]
    )
  }
}

extension HealthPermissions {
  public struct MockRequester: Requester {
    public var shouldFail = false

    public init() {}

    public func requestCanIClimbPermissions() async throws {
      struct SomeError: Error {}

      if self.shouldFail {
        throw SomeError()
      }
    }
  }
}

// MARK: - Query

extension HealthPermissions {
  public static let requestMutation = RequestMutation()
    .alerts(success: .connectToHealthKitSuccess, failure: .connectToHealthKitFailure)
    .previewDelay(shouldDisable: true)

  public struct RequestMutation: MutationRequest, Hashable {
    public func mutate(
      with arguments: Void,
      in context: QueryContext,
      with continuation: QueryContinuation<Void>
    ) async throws {
      @Dependency(HealthPermissions.self) var permissions
      try await permissions.request()
    }
  }
}

// MARK: - AlertState

extension AlertState where Action == Never {
  public static let connectToHealthKitFailure = Self {
    TextState("Failed to Connect to HealthKit")
  } message: {
    TextState("Please try again later.")
  }

  public static let connectToHealthKitSuccess = Self {
    TextState("Successfully Connected to HealthKit")
  } message: {
    TextState("Enjoy your climbing journey!")
  }
}
