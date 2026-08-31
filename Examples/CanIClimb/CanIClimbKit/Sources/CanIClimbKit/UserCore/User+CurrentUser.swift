import Dependencies

extension User {
  public protocol CurrentUser: Sendable {
    func signIn(with credentials: SignInCredentials) async throws
    func signOut() async throws
    func localUser() async throws -> User?
    func currentStatus() async throws -> CurrentStatus
    func edit(with edit: Edit) async throws -> User
    func delete() async throws
  }

  public enum CurrentUserKey {}
}

extension User.CurrentUserKey: DependencyKey {
  public static var liveValue: any User.CurrentUser {
    CurrentUser.shared
  }
}

extension User {
  @MainActor
  public final class MockCurrentUser: CurrentUser {
    public var requiredCredentials: SignInCredentials?
    public var signOutError: (any Error)?
    public private(set) var signOutCount = 0

    public var localUserValue: User?
    public var currentStatusResult: Result<CurrentStatus, any Error>

    public private(set) var edits = [Edit]()
    public var editResult: Result<User, any Error>?

    public var deleteError: (any Error)?
    public private(set) var deleteCount = 0

    public init(
      currentStatusResult: Result<CurrentStatus, any Error> = .success(.unauthorized),
      editResult: Result<User, any Error>? = nil
    ) {
      self.currentStatusResult = currentStatusResult
      self.editResult = editResult
    }

    public func signIn(with credentials: SignInCredentials) async throws {
      if credentials != self.requiredCredentials {
        throw InvalidCredentialsError()
      }
    }

    public func signOut() async throws {
      if let error = self.signOutError {
        throw error
      }
      self.signOutCount += 1
    }

    public func localUser() async throws -> User? {
      self.localUserValue
    }

    public func currentStatus() async throws -> CurrentStatus {
      try self.currentStatusResult.get()
    }

    public func edit(with edit: Edit) async throws -> User {
      self.edits.append(edit)
      return try self.editResult?.get()
        ?? User(id: User.mock1.id, name: edit.name, subtitle: edit.subtitle)
    }

    public func delete() async throws {
      if let error = self.deleteError {
        throw error
      }
      self.deleteCount += 1
    }

    private struct InvalidCredentialsError: Error {}
  }
}
