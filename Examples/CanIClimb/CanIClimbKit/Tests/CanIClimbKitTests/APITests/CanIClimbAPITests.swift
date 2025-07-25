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
    let resp = CanIClimbAPI.AccessTokenResponse.signIn
    let key = "test_refresh_token"
    let api = CanIClimbAPI(
      transport: .mock { _ in (200, .json(resp)) },
      refreshTokenStorageKey: key,
      secureStorage: self.storage
    )

    expectNoDifference(self.storage[key], nil)
    try await api.signIn(with: credentials)
    expectNoDifference(self.storage[key], Data(resp.refreshToken!.utf8))
  }

  @Test("Signs User In, Uses Access Token To Access User")
  func signInUsesAccessTokenToAccessUser() async throws {
    let credentials = User.SignInCredentials.mock
    let userResponse = User(id: credentials.userId, name: credentials.name)
    let tokenResponse = CanIClimbAPI.AccessTokenResponse.signIn
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
    let tokenResponse1 = CanIClimbAPI.AccessTokenResponse.signIn
    let tokenResponse2 = CanIClimbAPI.AccessTokenResponse.refresh
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
    let tokenResponse1 = CanIClimbAPI.AccessTokenResponse.signIn
    let tokenResponse2 = CanIClimbAPI.AccessTokenResponse.refresh
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

  @Test("Removes Refresh Token When Signing Out")
  func removeRefreshTokenWhenSigningOut() async throws {
    let tokenResponse = CanIClimbAPI.AccessTokenResponse.signIn
    let api = CanIClimbAPI(
      transport: .mock { request in
        if request.url?.path() == "/auth/sign-in" {
          return (200, .json(tokenResponse))
        } else if request.url?.path() == "/auth/sign-out" {
          return (204, .data(Data()))
        }
        return (401, .data(Data()))
      },
      secureStorage: self.storage
    )

    try await api.signIn(with: .mock)
    try await api.signOut()

    await #expect(throws: User.UnauthorizedError.self) {
      try await api.user()
    }
  }

  @Test("Throws Error When Sign Out Returns Non-204")
  func throwsErrorWhenSignOutReturnsNon204() async throws {
    let tokenResponse = CanIClimbAPI.AccessTokenResponse.signIn
    let api = CanIClimbAPI(
      transport: .mock { request in
        if request.url?.path() == "/auth/sign-in" {
          return (200, .json(tokenResponse))
        } else if request.url?.path() == "/auth/sign-out" {
          return (400, .data(Data()))
        }
        return (401, .data(Data()))
      },
      secureStorage: self.storage
    )

    try await api.signIn(with: .mock)
    await #expect(throws: CanIClimbAPI.SignOutFailure(statusCode: 400)) {
      try await api.signOut()
    }
  }

  @Test("Removes Refresh Token When Account Deleted")
  func removeRefreshTokenWhenAccountDeleted() async throws {
    let tokenResponse = CanIClimbAPI.AccessTokenResponse.signIn
    let api = CanIClimbAPI(
      transport: .mock { request in
        if request.url?.path() == "/auth/sign-in" {
          return (200, .json(tokenResponse))
        } else if request.url?.path() == "/user" && request.httpMethod == "DELETE" {
          return (204, .data(Data()))
        }
        return (401, .data(Data()))
      },
      secureStorage: self.storage
    )

    try await api.signIn(with: .mock)
    try await api.deleteUser()

    await #expect(throws: User.UnauthorizedError.self) {
      try await api.user()
    }
  }

  @Test("Throws Error When Delete Account Returns Non-204")
  func throwsErrorWhenDeleteAccountReturnsNon204() async throws {
    let tokenResponse = CanIClimbAPI.AccessTokenResponse.signIn
    let api = CanIClimbAPI(
      transport: .mock { request in
        if request.url?.path() == "/auth/sign-in" {
          return (200, .json(tokenResponse))
        }
        return (400, .data(Data()))
      },
      secureStorage: self.storage
    )

    try await api.signIn(with: .mock)

    await #expect(throws: CanIClimbAPI.DeleteUserFailure(statusCode: 400)) {
      try await api.deleteUser()
    }
  }

  @Test("Throws Unauthorized Error When Endpoint Responds With 401 and No Refresh Token Available")
  func throwsUnauthorizedErrorWhenEndpointRespondsWith403AndNoRefreshTokenAvailable() async throws {
    let api = CanIClimbAPI(
      transport: .mock { _ in (401, .data(Data())) },
      secureStorage: self.storage
    )
    await #expect(throws: User.UnauthorizedError.self) {
      try await api.user()
    }
  }

  @Test("Edits User")
  func editsUser() async throws {
    let tokenResponse = CanIClimbAPI.AccessTokenResponse.signIn

    var editedUser = User.mock1
    editedUser.subtitle = "Edited"

    let edit = User.Edit(name: editedUser.name, subtitle: editedUser.subtitle)

    let api = CanIClimbAPI(
      transport: .mock { [editedUser] request in
        if request.url?.path() == "/auth/sign-in" {
          return (200, .json(tokenResponse))
        } else if request.url?.path() == "/user"
          && request.httpMethod == "PATCH"
          && request.hasBody(edit)
        {
          return (200, .json(editedUser))
        }
        return (400, .data(Data()))
      },
      secureStorage: self.storage
    )

    try await api.signIn(with: .mock)

    let user = try await api.editUser(with: edit)
    expectNoDifference(user, editedUser)
  }

  @Test("Nil When 404s For Mountain Request")
  func nilWhen404sForeMountainRequest() async throws {
    let api = CanIClimbAPI(
      transport: .mock { _ in (404, .data(Data())) },
      secureStorage: self.storage
    )
    let mountain = try await api.mountain(with: Mountain.ID(UUID()))
    expectNoDifference(mountain, nil)
  }

  @Test("Returns Mountain Details")
  func returnsMountainDetails() async throws {
    let api = CanIClimbAPI(
      transport: .mock { request in
        if request.url?.path() == "/mountain/\(Mountain.mock1.id)" {
          return (200, .json(Mountain.mock1))
        }
        return (404, .data(Data()))
      },
      secureStorage: self.storage
    )
    let mountain = try await api.mountain(with: Mountain.mock1.id)
    expectNoDifference(mountain, .mock1)
  }

  @Test("Returns Mountain Search Results For Text")
  func returnsMountainSearchResultsForText() async throws {
    let expectedResult = Mountain.SearchResult(mountains: [.mock1], hasNextPage: false)
    let api = CanIClimbAPI(
      transport: .mock { request in
        if request.url?.path() == "/mountains" && request.url?.query() == "page=1&type=text&text=st"
        {
          return (200, .json(expectedResult))
        }
        return (400, .data(Data()))
      },
      secureStorage: self.storage
    )
    let searchResult = try await api.searchMountains(
      by: Mountain.SearchRequest(search: Mountain.Search(text: "st"), page: 1)
    )
    expectNoDifference(searchResult, expectedResult)
  }

  @Test("Returns Recommended Mountain Search Results")
  func returnsRecommendedMountainSearchResults() async throws {
    let expectedResult = Mountain.SearchResult(mountains: [.mock1], hasNextPage: false)
    let api = CanIClimbAPI(
      transport: .mock { request in
        if request.url?.path() == "/mountains" && request.url?.query() == "page=0&type=recommended"
        {
          return (200, .json(expectedResult))
        }
        return (400, .data(Data()))
      },
      secureStorage: self.storage
    )
    let searchResult = try await api.searchMountains(
      by: Mountain.SearchRequest(search: .recommended, page: 0)
    )
    expectNoDifference(searchResult, expectedResult)
  }

  @Test("Returns Planned Mountain Search Results")
  func returnsPlannedMountainSearchResults() async throws {
    let expectedResult = Mountain.SearchResult(mountains: [.mock1], hasNextPage: false)
    let api = CanIClimbAPI(
      transport: .mock { request in
        if request.url?.path() == "/mountains" && request.url?.query() == "page=0&type=planned" {
          return (200, .json(expectedResult))
        }
        return (400, .data(Data()))
      },
      secureStorage: self.storage
    )
    let searchResult = try await api.searchMountains(
      by: Mountain.SearchRequest(search: .planned, page: 0)
    )
    expectNoDifference(searchResult, expectedResult)
  }
}

extension CanIClimbAPI.AccessTokenResponse {
  fileprivate static let signIn = Self(
    accessToken: "access",
    refreshToken: "refresh"
  )
  fileprivate static let refresh = Self(
    accessToken: "access2",
    refreshToken: nil
  )
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

  fileprivate func hasBody<T: Decodable & Equatable>(_ body: T) -> Bool {
    let requestBody = try? JSONDecoder().decode(T.self, from: self.httpBody ?? Data())
    guard let requestBody else { return false }
    return requestBody == body
  }
}
