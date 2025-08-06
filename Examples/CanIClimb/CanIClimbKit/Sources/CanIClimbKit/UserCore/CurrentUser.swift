import Dependencies
import GRDB
import Query
import StructuredQueriesGRDB

// MARK: - CurrentUser

public final class CurrentUser: Sendable {
  private let database: any DatabaseWriter
  private let api: CanIClimbAPI

  public init(database: any DatabaseWriter, api: CanIClimbAPI) {
    self.database = database
    self.api = api
  }
}

// MARK: - Shared Instance

extension CurrentUser {
  public static let shared: CurrentUser = {
    @Dependency(\.defaultDatabase) var database
    return CurrentUser(database: database, api: .shared)
  }()
}

// MARK: - Authenticator

extension CurrentUser: User.Authenticator {
  public func signIn(with credentials: CachedUserRecord.SignInCredentials) async throws {
    try await self.api.signIn(with: credentials)
  }

  public func signOut() async throws {
    try await self.api.signOut()
    try await self.removeLocalUser()
  }
}

// MARK: - CurrentLoader

extension CurrentUser: User.CurrentLoader {
  public func localUser() async throws -> User? {
    try await self.database.read { db in
      let id = LocalInternalMetricsRecord.find(in: db).currentUserId
      return try id.flatMap { try CachedUserRecord.find($0).fetchOne(db) }
    }
  }

  public func user() async throws -> User {
    let user = try await self.api.user()
    try await self.saveLocalUser(user)
    return user
  }
}

// MARK: - Editor

extension CurrentUser: User.Editor {
  public func edit(with edit: User.Edit) async throws -> User {
    let user = try await self.api.editUser(with: edit)
    try await self.saveLocalUser(user)
    return user
  }
}

// MARK: - AccountDeleter

extension CurrentUser: User.AccountDeleter {
  public func delete() async throws {
    try await self.api.deleteUser()
    try await self.removeLocalUser()
  }
}

extension CurrentUser {
  private func removeLocalUser() async throws {
    try await self.database.write { db in
      try LocalInternalMetricsRecord.update(in: db) { $0.currentUserId = nil }
      try CachedUserRecord.delete().execute(db)
    }
  }

  private func saveLocalUser(_ user: User) async throws {
    try await self.database.write { db in
      try LocalInternalMetricsRecord.update(in: db) { $0.currentUserId = user.id }
      try CachedUserRecord.upsert { CachedUserRecord.Draft(user) }
        .execute(db)
    }
  }
}
