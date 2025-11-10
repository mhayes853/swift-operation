import CoreLocation
import Dependencies
import Operation

// MARK: - UserLocation

public protocol UserLocation: Sendable {
  func read() async throws -> LocationReading
  func requestAuthorization() async -> Bool
}

public enum UserLocationKey: DependencyKey {
  public static var liveValue: any UserLocation {
    fatalError("Set this value on the MainActor at the root.")
  }
}

public struct UserLocationUnauthorizedError: Error {
  public init() {}
}

// MARK: - MockUserLocation

@MainActor
public final class MockUserLocation: UserLocation {
  private struct NoReadingError: Error {}

  public var currentReading = Result<LocationReading, any Error>.failure(NoReadingError())
  public var isAuthorized = true

  public init() {}

  public func read() async throws -> LocationReading {
    try self.currentReading.get()
  }

  public func requestAuthorization() async -> Bool {
    self.isAuthorized
  }
}

// MARK: - RequestUserPermissionMutation

extension LocationReading {
  public static let requestUserPermissionMutation = RequestUserPermissionMutation()

  public struct RequestUserPermissionMutation: MutationRequest, Hashable, Sendable {
    public typealias Arguments = Void

    public func mutate(
      isolation: isolated (any Actor)?,
      with arguments: Void,
      in context: OperationContext,
      with continuation: OperationContinuation<Bool, Never>
    ) async -> Bool {
      @Dependency(\.defaultOperationClient) var client
      @Dependency(UserLocationKey.self) var userLocation
      let isAuthorized = await userLocation.requestAuthorization()
      if isAuthorized {
        Task.immediate { try await client.store(for: LocationReading.userQuery).fetch() }
      }
      return isAuthorized
    }
  }
}

// MARK: - UserQuery

extension LocationReading {
  public static let userQuery = UserQuery()
    .stale(after: .fiveMinutes)
    .logDuration()

  public struct UserQuery: QueryRequest, Hashable, Sendable {
    public func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<LocationReading, any Error>
    ) async throws -> LocationReading {
      @Dependency(UserLocationKey.self) var userLocation
      return try await userLocation.read()
    }
  }
}
