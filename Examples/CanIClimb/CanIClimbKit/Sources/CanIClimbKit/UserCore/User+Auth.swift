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
    @Dependency(User.CurrentUserKey.self) var users
    @Dependency(\.defaultOperationClient) var client

    try await users.signIn(with: arguments.credentials)

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
    @Dependency(User.CurrentUserKey.self) var users
    @Dependency(\.defaultOperationClient) var client

    try await users.signOut()

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
