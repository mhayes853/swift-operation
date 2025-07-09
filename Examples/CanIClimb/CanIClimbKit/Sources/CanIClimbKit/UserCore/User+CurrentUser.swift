import Dependencies
import GRDB
import Query
import StructuredQueriesGRDB

// MARK: - Current Loader

extension User {
  public protocol CurrentLoader: Sendable {
    func user() async throws -> User
  }

  public enum CurrentLoaderKey: DependencyKey {
    public static let liveValue: any User.CurrentLoader = CanIClimbAPI.shared
  }
}

extension CanIClimbAPI: User.CurrentLoader {}

extension User {
  @MainActor
  public final class MockCurrentLoader: CurrentLoader {
    public var result: Result<User, any Error>

    public init(result: Result<User, any Error>) {
      self.result = result
    }

    public func user() async throws -> User {
      try self.result.get()
    }
  }
}

// MARK: - Query

extension User {
  public static let currentQuery = CurrentQuery()

  public struct CurrentQuery: QueryRequest, Hashable {
    public func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<User>
    ) async throws -> User {
      @Dependency(\.defaultDatabase) var database
      @Dependency(User.CurrentLoaderKey.self) var loader

      let cachedUser = try? await database.read { db in
        let id = LocalInternalMetricsRecord.find(in: db).currentUserId
        return try id.flatMap { try CachedUserRecord.find($0).fetchOne(db) }
      }
      if let cachedUser {
        continuation.yield(User(cached: cachedUser))
      }
      let user = try await loader.user()
      try? await database.write { db in
        try LocalInternalMetricsRecord.update(in: db) { $0.currentUserId = user.id }
        try CachedUserRecord.upsert { CachedUserRecord.Draft(CachedUserRecord(user: user)) }
          .execute(db)
      }
      return user
    }
  }
}
