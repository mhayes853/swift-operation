import Foundation
import IssueReporting
import Query

// MARK: - CanIClimbAPI

public final class CanIClimbAPI: Sendable {
  private let baseURL: URL
  private let transport: any HTTPDataTransport
  private let secureStorage: any SecureStorage
  private let accessTokenStore: QueryStore<AccessTokenMutation.State>

  public init(
    baseURL: URL = .canIClimbAPIBase,
    delayer: (any QueryDelayer)? = isTesting ? .noDelay : nil,
    transport: any HTTPDataTransport,
    secureStorage: any SecureStorage
  ) {
    self.baseURL = baseURL
    self.transport = transport
    self.secureStorage = secureStorage

    // NB: Use a query store to control fetches to the access token to prevent duplicate concurrent
    // requests from either signing the user in, or refreshing the access token. We can also add
    // automatic retries and exponential backoff with the `retry` modifier.
    //
    // Additionally, we'll use a detached store instead of one vended from a `QueryClient` because
    // there will be no subscribers to this store, is not displayed directly in the UI, and to
    // avoid the default store cache from evicting the store from memory when the app recieves a
    // memory pressure notification.
    self.accessTokenStore = .detached(
      mutation: AccessTokenMutation()
        .retry(limit: 3, delayer: delayer)
        .deduplicated()
    )
  }
}

// MARK: - Shared

extension CanIClimbAPI {
  // NB: In a production application with a real API, you can use URLSession.shared.

  public static let shared = CanIClimbAPI(
    transport: DemoAPITransport(),
    secureStorage: KeychainSecureStorage.shared
  )
}

// MARK: - Constants

extension URL {
  public static let canIClimbAPIBase = URL(string: "https://api.caniclimb.com")!
}

// MARK: - Auth

extension CanIClimbAPI {
  public func signIn(with credentials: User.SignInCredentials) async throws {
    _ = try await self.accessTokenStore.mutate(
      with: AccessTokenMutation.Arguments(api: self, request: .signIn(credentials))
    )
  }

  public func signOut() async throws {
    let (_, resp) = try await self.performRequestWithAccessToken(
      path: "/auth/sign-out"
    ) { request in
      request.httpMethod = "POST"
      return try await self.transport.data(for: request)
    }
    guard (resp as? HTTPURLResponse)?.statusCode == 204 else {
      throw SignOutFailure(statusCode: (resp as? HTTPURLResponse)?.statusCode)
    }
    self.secureStorage[_refreshTokenSecureStorageKey] = nil
  }

  public struct SignOutFailure: Hashable, Error {
    public let statusCode: Int?

    public init(statusCode: Int?) {
      self.statusCode = statusCode
    }
  }
}

// MARK: - User

extension CanIClimbAPI {
  public func user() async throws -> User {
    let (data, _) = try await self.performRequestWithAccessToken(path: "/user") { request in
      try await self.transport.data(for: request)
    }
    return try JSONDecoder().decode(User.self, from: data)
  }
}

// MARK: - Edit User

extension CanIClimbAPI {
  public func editUser(with edit: User.Edit) async throws -> User {
    let body = try JSONEncoder().encode(edit)
    let (data, _) = try await self.performRequestWithAccessToken(path: "/user") { request in
      request.httpMethod = "PATCH"
      request.httpBody = body
      return try await self.transport.data(for: request)
    }
    return try JSONDecoder().decode(User.self, from: data)
  }
}

// MARK: - Delete User

extension CanIClimbAPI {
  public func deleteUser() async throws {
    let (_, resp) = try await self.performRequestWithAccessToken(path: "/user") { request in
      request.httpMethod = "DELETE"
      return try await self.transport.data(for: request)
    }
    guard (resp as? HTTPURLResponse)?.statusCode == 204 else {
      throw DeleteUserFailure(statusCode: (resp as? HTTPURLResponse)?.statusCode)
    }
    self.secureStorage[_refreshTokenSecureStorageKey] = nil
  }

  public struct DeleteUserFailure: Hashable, Error {
    public let statusCode: Int?

    public init(statusCode: Int?) {
      self.statusCode = statusCode
    }
  }
}

// MARK: - Access Token

extension CanIClimbAPI {
  private func performRequestWithAccessToken(
    path: String,
    perform: (inout URLRequest) async throws -> (Data, URLResponse)
  ) async throws -> (Data, URLResponse) {
    var request = URLRequest(url: self.baseURL.appending(path: path))
    var accessToken = self.accessTokenStore.currentValue ?? ""
    if accessToken.isEmpty {
      accessToken = try await self.accessTokenStore.mutate(
        with: AccessTokenMutation.Arguments(api: self, request: .refresh)
      )
    }
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await perform(&request)
    if (response as? HTTPURLResponse)?.statusCode == 401 {
      accessToken = try await self.accessTokenStore.mutate(
        with: AccessTokenMutation.Arguments(api: self, request: .refresh)
      )
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      return try await perform(&request)
    } else {
      return (data, response)
    }
  }

  public struct AccessTokenResponse: Codable, Hashable, Sendable {
    public let accessToken: AccessToken
    public let refreshToken: String?

    public init(accessToken: AccessToken, refreshToken: String?) {
      self.accessToken = accessToken
      self.refreshToken = refreshToken
    }
  }

  public typealias AccessToken = String

  private enum AccessTokenRequest: Hashable, Sendable {
    case refresh
    case signIn(User.SignInCredentials)
  }

  private struct AccessTokenMutation: MutationRequest, Hashable {
    struct Arguments: Sendable {
      let api: CanIClimbAPI
      let request: AccessTokenRequest
    }

    func mutate(
      with arguments: Arguments,
      in context: QueryContext,
      with continuation: QueryContinuation<AccessToken>
    ) async throws -> AccessToken {
      switch arguments.request {
      case .refresh: try await arguments.api.refresh()
      case .signIn(let credentials): try await arguments.api.accessToken(for: credentials)
      }
    }
  }

  private func refresh() async throws -> AccessToken {
    var request = URLRequest(url: self.baseURL.appending(path: "/auth/refresh"))
    request.httpMethod = "POST"
    guard let token = self.secureStorage[_refreshTokenSecureStorageKey] else {
      throw CanIClimbAPI.UnauthorizedError()
    }
    let refreshToken = String(decoding: token, as: UTF8.self)
    request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")
    let (data, _) = try await self.transport.data(for: request)
    return try JSONDecoder().decode(AccessTokenResponse.self, from: data).accessToken
  }

  private func accessToken(for credentials: User.SignInCredentials) async throws -> AccessToken {
    var request = URLRequest(url: self.baseURL.appending(path: "/auth/sign-in"))
    request.httpMethod = "POST"
    request.httpBody = try JSONEncoder().encode(credentials)
    let (data, _) = try await self.transport.data(for: request)
    let response = try JSONDecoder().decode(AccessTokenResponse.self, from: data)
    if let token = response.refreshToken {
      self.secureStorage[_refreshTokenSecureStorageKey] = Data(token.utf8)
    }
    return response.accessToken
  }
}

public let _refreshTokenSecureStorageKey = "canIClimbAPI_RefreshToken"

// MARK: - UnauthorizedError

extension CanIClimbAPI {
  public struct UnauthorizedError: Error {}
}
