import Dependencies
import SharingOperation

// MARK: - Current Loader

extension User {
  public protocol CurrentLoader: Sendable {
    func localUser() async throws -> User?
    func user() async throws -> User?
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
    public var result: Result<User?, any Error>
    public var localUser: User?

    public init(result: Result<User?, any Error>) {
      self.result = result
    }

    public func localUser() async throws -> User? {
      self.localUser
    }

    public func user() async throws -> User? {
      try self.result.get()
    }
  }
}

// MARK: - Query

extension User {
  public static let currentQuery = CurrentQuery()

  public struct CurrentQuery: QueryRequest, Hashable, Sendable {
    public func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<User?, any Error>
    ) async throws -> User? {
      let loader = Dependency(User.CurrentLoaderKey.self).wrappedValue

      async let user = loader.user()
      if let localUser = try await loader.localUser() {
        continuation.yield(localUser)
      }
      return try await user
    }
  }
}
