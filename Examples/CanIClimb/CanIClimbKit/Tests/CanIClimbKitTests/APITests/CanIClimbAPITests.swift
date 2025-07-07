import CanIClimbKit
import CustomDump
import Foundation
import Testing

@Suite("CanIClimbAPI tests")
struct CanIClimbAPITests {
  private let storage = InMemorySecureStorage()

  @Test("Signs User In, Saves Refresh Token Securely")
  func signInSavesRefreshTokenSecurely() async throws {
    let credentials = User.SignInCredentials.mock
    let resp = CanIClimbAPI.AccessTokenResponse(
      accessToken: "access",
      refreshToken: "refresh"
    )
    let api = CanIClimbAPI(
      transport: .mock { _ in (200, .json(resp)) },
      secureStorage: self.storage
    )

    expectNoDifference(self.storage[_refreshTokenSecureStorageKey], nil)
    try await api.signIn(with: credentials)
    expectNoDifference(self.storage[_refreshTokenSecureStorageKey], Data(resp.refreshToken!.utf8))
  }

  @Test("Signs User In, Uses Access Token To Access User")
  func signInUsesAccessTokenToAccessUser() async throws {
    let credentials = User.SignInCredentials.mock
    let userResponse = User(id: credentials.userId, name: credentials.name)
    let tokenResponse = CanIClimbAPI.AccessTokenResponse(
      accessToken: "access",
      refreshToken: "refresh"
    )
    let api = CanIClimbAPI(
      transport: .mock { request in
        if request.url?.path() == "/auth/sign-in" {
          return (200, .json(tokenResponse))
        } else if request.url?.path() == "/user" && request.hasToken(tokenResponse.accessToken) {
          return (200, .json(userResponse))
        }
        return nil
      },
      secureStorage: self.storage
    )

    try await api.signIn(with: credentials)
    let user = try await api.user()
    expectNoDifference(user, userResponse)
  }

  @Test("Refreshes Access Token When Not Present")
  func refreshTokenWhenNotPresent() async throws {
    let credentials = User.SignInCredentials.mock
    let userResponse = User(id: credentials.userId, name: credentials.name)
    let tokenResponse1 = CanIClimbAPI.AccessTokenResponse(
      accessToken: "access",
      refreshToken: "refresh"
    )
    let tokenResponse2 = CanIClimbAPI.AccessTokenResponse(
      accessToken: "access2",
      refreshToken: nil
    )
    let api = CanIClimbAPI(
      transport: .mock { _ in (200, .json(tokenResponse1)) },
      secureStorage: self.storage
    )

    try await api.signIn(with: credentials)

    let api2 = CanIClimbAPI(
      transport: .mock { request in
        if request.url?.path() == "/auth/refresh" && request.hasToken(tokenResponse1.refreshToken) {
          return (200, .json(tokenResponse2))
        } else if request.url?.path() == "/user" && request.hasToken(tokenResponse2.accessToken) {
          return (200, .json(userResponse))
        }
        return nil
      },
      secureStorage: self.storage
    )
    let user = try await api2.user()
    expectNoDifference(user, userResponse)
  }

  @Test("Refreshes Access Token When API 401s")
  func refreshTokenWhenAPI401s() async throws {
    let credentials = User.SignInCredentials.mock
    let userResponse = User(id: credentials.userId, name: credentials.name)
    let tokenResponse1 = CanIClimbAPI.AccessTokenResponse(
      accessToken: "access",
      refreshToken: "refresh"
    )
    let tokenResponse2 = CanIClimbAPI.AccessTokenResponse(
      accessToken: "access2",
      refreshToken: nil
    )
    let api = CanIClimbAPI(
      transport: .mock { request in
        if request.url?.path() == "/auth/sign-in" {
          return (200, .json(tokenResponse1))
        } else if request.url?.path() == "/auth/refresh"
          && request.hasToken(tokenResponse1.refreshToken)
        {
          return (200, .json(tokenResponse2))
        } else if request.url?.path() == "/user" && request.hasToken(tokenResponse2.accessToken) {
          return (200, .json(userResponse))
        }
        return (401, .data(Data()))
      },
      secureStorage: self.storage
    )

    try await api.signIn(with: credentials)
    let user = try await api.user()
    expectNoDifference(user, userResponse)
  }

  @Test("Throws Unauthorized Error When Endpoint Responds With 401 and No Refresh Token Available")
  func throwsUnauthorizedErrorWhenEndpointRespondsWith403AndNoRefreshTokenAvailable() async throws {
    let api = CanIClimbAPI(
      transport: .mock { _ in (401, .data(Data())) },
      secureStorage: self.storage
    )
    await #expect(throws: CanIClimbAPI.UnauthorizedError.self) {
      try await api.user()
    }
  }
}

extension User.SignInCredentials {
  fileprivate static let mock = Self(
    userId: "test",
    name: PersonNameComponents(givenName: "Blob", familyName: "Blob"),
    token: Data("blob".utf8)
  )
}

extension URLRequest {
  fileprivate func hasToken(_ token: String?) -> Bool {
    allHTTPHeaderFields?["Authorization"] == "Bearer \(token ?? "")"
  }
}
