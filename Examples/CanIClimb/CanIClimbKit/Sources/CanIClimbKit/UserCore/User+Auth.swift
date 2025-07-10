import AuthenticationServices
import Dependencies
import Foundation
import SharingQuery

// MARK: - SignInCredentials

extension User {
  public struct SignInCredentials: Hashable, Sendable, Codable {
    public let userId: User.ID
    public let name: PersonNameComponents
    public let identityToken: Data

    public init(userId: User.ID, name: PersonNameComponents, token: Data) {
      self.userId = userId
      self.name = name
      self.identityToken = token
    }
  }
}

extension User.SignInCredentials {
  public init?(authorization: ASAuthorization) {
    guard
      let credentials = authorization.credential as? ASAuthorizationAppleIDCredential,
      let fullName = credentials.fullName,
      let token = credentials.identityToken
    else {
      return nil
    }
    self.init(userId: User.ID(rawValue: credentials.user), name: fullName, token: token)
  }
}

// MARK: - Authenticator

extension User {
  public protocol Authenticator: Sendable {
    func signIn(with credentials: SignInCredentials) async throws
    func signOut() async throws
  }

  public enum AuthenticatorKey: DependencyKey {
    public static let liveValue: any User.Authenticator = CanIClimbAPI.shared
  }
}

extension CanIClimbAPI: User.Authenticator {}

extension User {
  @MainActor
  public final class MockAuthenticator: User.Authenticator {
    public var requiredCredentials: User.SignInCredentials?
    public var signOutError: (any Error)?
    public private(set) var signOutCount = 0

    public init() {}

    public func signIn(with credentials: User.SignInCredentials) async throws {
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

    private struct InvalidCredentialsError: Error {}
  }
}

// MARK: - Mutations

extension User {
  public static let signInMutation = SignInMutation()

  public struct SignInMutation: MutationRequest, Hashable {
    public struct Arguments: Sendable {
      let credentials: User.SignInCredentials

      public init(credentials: User.SignInCredentials) {
        self.credentials = credentials
      }
    }

    public func mutate(
      with arguments: Arguments,
      in context: QueryContext,
      with continuation: QueryContinuation<Void>
    ) async throws {
      @Dependency(User.AuthenticatorKey.self) var authenticator
      @Dependency(\.defaultQueryClient) var client

      try await authenticator.signIn(with: arguments.credentials)
      let task = client.store(for: User.currentQuery).fetchTask()
      Task { try await task.runIfNeeded() }
    }
  }
}

extension User {
  public static let signOutMutation = SignOutMutation()

  public struct SignOutMutation: MutationRequest, Hashable {
    public func mutate(
      with arguments: Void,
      in context: QueryContext,
      with continuation: QueryContinuation<Void>
    ) async throws {
      @Dependency(User.AuthenticatorKey.self) var authenticator
      @Dependency(\.defaultQueryClient) var client
      @Dependency(CurrentUser.self) var currentUser

      try await authenticator.signOut()
      client.store(for: User.currentQuery).currentValue = nil
      try await currentUser.switchUserId(to: nil)
    }
  }
}
