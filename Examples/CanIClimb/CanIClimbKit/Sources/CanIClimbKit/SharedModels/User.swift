import AuthenticationServices
import Dependencies
import Foundation
import Tagged

// MARK: - User

public struct User: Hashable, Sendable, Identifiable, Codable {
  public typealias ID = Tagged<Self, String>

  public let id: ID
  public var name: PersonNameComponents

  public init(id: ID, name: PersonNameComponents) {
    self.id = id
    self.name = name
  }
}

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

// MARK: - CurrentLoader

extension User {
  public protocol CurrentLoader: Sendable {
    func user() async throws -> User
  }

  public enum CurrentLoaderKey: DependencyKey {
    public static let liveValue: any User.CurrentLoader = CanIClimbAPI.shared
  }
}

extension CanIClimbAPI: User.CurrentLoader {}
