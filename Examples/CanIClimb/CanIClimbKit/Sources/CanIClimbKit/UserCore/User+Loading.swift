import CasePaths
import Dependencies
import SharingOperation

// MARK: - Current Status

extension User {
  @CasePathable
  public enum CurrentStatus: Hashable, Sendable {
    case user(User)
    case unauthorized
  }
}

// MARK: - Current Loader

extension User {
  public protocol CurrentLoader: Sendable {
    func localUser() async throws -> User?
    func currentStatus() async throws -> CurrentStatus
  }

  public enum CurrentLoaderKey: DependencyKey {
    public static var liveValue: any User.CurrentLoader {
      CurrentUser.shared
    }
  }
}

extension User {
  @MainActor
  public final class MockCurrentLoader: CurrentLoader {
    public var result: Result<CurrentStatus, any Error>
    public var localUser: User?

    public init(result: Result<CurrentStatus, any Error>) {
      self.result = result
    }

    public func localUser() async throws -> User? {
      self.localUser
    }

    public func currentStatus() async throws -> CurrentStatus {
      try self.result.get()
    }
  }
}

// MARK: - Query

extension User {
  @QueryRequest
  public static func currentStatusQuery(
    continuation: OperationContinuation<CurrentStatus, any Error>
  ) async throws -> CurrentStatus {
    let loader = Dependency(User.CurrentLoaderKey.self).wrappedValue

    async let status = loader.currentStatus()
    if let localUser = try await loader.localUser() {
      continuation.yield(.user(localUser))
    }
    return try await status
  }
}
