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

    public init() {}

    public func signIn(with credentials: User.SignInCredentials) async throws {
      if credentials != self.requiredCredentials {
        throw InvalidCredentialsError()
      }
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
