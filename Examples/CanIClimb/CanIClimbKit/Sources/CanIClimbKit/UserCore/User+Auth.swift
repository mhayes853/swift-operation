import AuthenticationServices
import Dependencies
import Foundation
import SharingOperation
import SwiftNavigation

// MARK: - SignInCredentials

extension User {
  public struct SignInCredentials: Hashable, Sendable, Codable {
    public let userId: User.ID
    public let name: User.Name
    public let identityToken: Data

    public init(userId: User.ID, name: User.Name, token: Data) {
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
    self.init(
      userId: User.ID(rawValue: credentials.user),
      name: User.Name(components: fullName),
      token: token
    )
  }
}

extension User.SignInCredentials {
  public static let mock1 = Self(userId: User.mock1.id, name: User.mock1.name, token: Data())
  public static let mock2 = Self(userId: User.mock2.id, name: User.mock2.name, token: Data())
}

// MARK: - UnauthorizedError

extension User {
  public struct UnauthorizedError: Error {
    public init() {}
  }
}

// MARK: - Authenticator

extension User {
  public protocol Authenticator: Sendable {
    func signIn(with credentials: SignInCredentials) async throws
    func signOut() async throws
  }

  public enum AuthenticatorKey: DependencyKey {
    public static var liveValue: any User.Authenticator {
      CurrentUser.shared
    }
  }
}

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
  public struct SignInArguments: Sendable {
    let credentials: User.SignInCredentials

    public init(credentials: User.SignInCredentials) {
      self.credentials = credentials
    }
  }

  public static var signInMutation: some MutationRequest<SignInArguments, Void, any Error> {
    Self.$signInMutation.alerts(success: .signInSuccess, failure: .signInFailure)
  }

  @MutationRequest
  private static func signInMutation(arguments: SignInArguments) async throws {
    @Dependency(User.AuthenticatorKey.self) var authenticator
    @Dependency(\.defaultOperationClient) var client

    try await authenticator.signIn(with: arguments.credentials)

    let userStore = client.store(for: User.$currentStatusQuery)
    // NB: Prevent deduplication against tasks in the process of being cancelled.
    await userStore.resetWaitingForAllActiveTasksToFinish()
    Task { try await userStore.fetch() }
  }
}

extension User {
  public static var signOutMutation: some MutationRequest<Void, Void, any Error> {
    Self.$signOutMutation.alerts(success: .signOutSuccess, failure: .signOutFailure)
  }

  @MutationRequest
  private static func signOutMutation() async throws {
    @Dependency(User.AuthenticatorKey.self) var authenticator
    @Dependency(\.defaultOperationClient) var client

    try await authenticator.signOut()

    let userStore = client.store(for: User.$currentStatusQuery)
    userStore.resetState()
    userStore.currentValue = .unauthorized
  }
}

// MARK: - AlertState

extension AlertState where Action == Never {
  public static let signInSuccess = Self {
    TextState("Success")
  } message: {
    TextState("You've signed in successfully. Enjoy climbing!")
  }

  public static let signInFailure = Self.remoteOperationError {
    TextState("Failed to Sign In")
  } message: {
    TextState("An error occurred while signing in. Please try again later.")
  }

  public static let signOutSuccess = Self {
    TextState("Success")
  } message: {
    TextState("You've signed out successfully. See you next time!")
  }

  public static let signOutFailure = Self.remoteOperationError {
    TextState("Failed to Sign Out")
  } message: {
    TextState("An error occurred while signing out. Please try again later.")
  }
}
