import Dependencies
import GRDB
import Query
import StructuredQueriesGRDB

// MARK: - CurrentUserStorage

public final class CurrentUser: Sendable {
  private let database: any DatabaseWriter

  public init(database: any DatabaseWriter) {
    self.database = database
  }
}

extension CurrentUser {
  public func localUser() async throws -> User? {
    try await self.database.read { db in
      let id = LocalInternalMetricsRecord.find(in: db).currentUserId
      return try id.flatMap { try CachedUserRecord.find($0).fetchOne(db) }
    }
  }
}

extension CurrentUser {
  public func user(using loader: some User.CurrentLoader) async throws -> User {
    let user = try await loader.user()
    try await self.saveLocalUser(user)
    return user
  }
}

extension CurrentUser {
  public func edit(with edit: User.Edit, using editor: some User.Editor) async throws -> User {
    let user = try await editor.editUser(with: edit)
    try await self.saveLocalUser(user)
    return user
  }
}

extension CurrentUser {
  public func delete(using deleter: some User.AccountDeleter) async throws {
    try await deleter.deleteUser()
    try await self.database.write { db in
      guard let id = LocalInternalMetricsRecord.find(in: db).currentUserId else { return }
      try LocalInternalMetricsRecord.update(in: db) { $0.currentUserId = nil }
      try CachedUserRecord.delete().where { $0.id.eq(id) }.execute(db)
    }
  }
}

extension CurrentUser {
  public func switchUserId(to id: User.ID?) async throws {
    try await self.database.write { db in
      try LocalInternalMetricsRecord.update(in: db) { $0.currentUserId = id }
    }
  }
}

extension CurrentUser {
  private func saveLocalUser(_ user: User) async throws {
    try await self.database.write { db in
      try LocalInternalMetricsRecord.update(in: db) { $0.currentUserId = user.id }
      try CachedUserRecord.upsert { CachedUserRecord.Draft(user) }
        .execute(db)
    }
  }
}

extension CurrentUser: DependencyKey {
  public static var liveValue: CurrentUser {
    @Dependency(\.defaultDatabase) var database
    return CurrentUser(database: database)
  }
}

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
      @Dependency(User.CurrentLoaderKey.self) var loader
      let currentUser = Dependency(CurrentUser.self).wrappedValue

      async let user = currentUser.user(using: loader)
      if let localUser = try await currentUser.localUser() {
        continuation.yield(localUser)
      }
      return try await user
    }
  }
}
