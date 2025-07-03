import Dependencies
import GRDB
import HealthKit
import StructuredQueriesGRDB

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
}

// MARK: - Request

extension HealthPermissions {
  public func request() async throws {
    try await self.requester.requestCanIClimbPermissions()
    try await self.database.write { db in
      var metrics = LocalInternalMetricsRecord.find(in: db)
      metrics.hasConnectedHealthKit = true
      try metrics.save(in: db)
    }
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

// MARK: - DependencyKey

extension HealthPermissions: DependencyKey {
  public static var liveValue: HealthPermissions {
    @Dependency(\.defaultDatabase) var database
    return HealthPermissions(database: database, requester: HKHealthStore.canIClimb)
  }
}
