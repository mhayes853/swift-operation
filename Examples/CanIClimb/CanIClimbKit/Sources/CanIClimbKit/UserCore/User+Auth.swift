import AuthenticationServices
import Dependencies
import Foundation
import SharingQuery
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
  public static let signInMutation = SignInMutation()
    .alerts(success: .signInSuccess, failure: .signInFailure)

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
      Task.immediate { try await client.store(for: User.currentQuery).fetch() }
    }
  }
}

extension User {
  public static let signOutMutation = SignOutMutation()
    .alerts(success: .signOutSuccess, failure: .signOutFailure)

  public struct SignOutMutation: MutationRequest, Hashable {
    public func mutate(
      with arguments: Void,
      in context: QueryContext,
      with continuation: QueryContinuation<Void>
    ) async throws {
      @Dependency(User.AuthenticatorKey.self) var authenticator
      @Dependency(\.defaultQueryClient) var client

      try await authenticator.signOut()
      let userStore = client.store(for: User.currentQuery)
      userStore.withExclusiveAccess {
        $0.currentValue = nil
        $0.setResult(to: .failure(User.UnauthorizedError()))
      }
    }
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
