import Foundation
import Logging
import Operation
import OrderedCollections
import Tagged
import UUIDV7

// MARK: - CanIClimbAPI

public final class CanIClimbAPI: Sendable {
  private let baseURL: URL
  private let transport: any HTTPDataTransport
  private let tokens: Tokens
  private let achieveQueue = SerialTaskQueue(priority: .userInitiated)

  public init(
    baseURL: URL = .canIClimbAPIBase,
    transport: any HTTPDataTransport,
    tokens: Tokens
  ) {
    self.baseURL = baseURL
    self.transport = transport
    self.tokens = tokens
  }
}

// MARK: - Shared

extension CanIClimbAPI {
  // NB: In a production application with a real API, you can use URLSession.shared for the
  // transport.

  public static let shared = CanIClimbAPI(
    transport: DummyBackend(),
    tokens: Tokens(client: .canIClimb, secureStorage: KeychainSecureStorage.shared)
  )
}

// MARK: - Constants

extension URL {
  public static let canIClimbAPIBase = URL(string: "https://api.caniclimb.com")!
}

// MARK: - Auth

extension CanIClimbAPI {
  public func signIn(with credentials: User.SignInCredentials) async throws {
    try await withCurrentLogger(Logger(label: "caniclimb.api.signin")) {
      _ = try await self.tokens.load(taskName: "sign-in") {
        let request = self.request(
          path: "/auth/sign-in",
          method: "POST",
          body: try JSONEncoder().encode(credentials)
        )
        let (data, _) = try await self.send(request)
        return try JSONDecoder().decode(Tokens.Response.self, from: data)
      }
    }
  }

  public func signOut() async throws {
    let (_, resp) = try await self.perform(self.request(path: "/auth/sign-out", method: "POST"))
    guard resp.statusCode == 204 else { throw SignOutFailure(statusCode: resp.statusCode) }
    await self.tokens.clear()
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
    let (data, _) = try await self.perform(self.request(path: "/user"))
    return try JSONDecoder().decode(User.self, from: data)
  }
}

// MARK: - Edit User

extension CanIClimbAPI {
  public func editUser(with edit: User.Edit) async throws -> User {
    let request = self.request(
      path: "/user",
      method: "PATCH",
      body: try JSONEncoder().encode(edit)
    )
    let (data, _) = try await self.perform(request)
    return try JSONDecoder().decode(User.self, from: data)
  }
}

// MARK: - Delete User

extension CanIClimbAPI {
  public func deleteUser() async throws {
    let (_, resp) = try await self.perform(self.request(path: "/user", method: "DELETE"))
    guard resp.statusCode == 204 else { throw DeleteUserFailure(statusCode: resp.statusCode) }
    await self.tokens.clear()
  }

  public struct DeleteUserFailure: Hashable, Error {
    public let statusCode: Int?

    public init(statusCode: Int?) {
      self.statusCode = statusCode
    }
  }
}

// MARK: - Mountains Searcher

extension CanIClimbAPI {
  public func searchMountains(
    by request: Mountain.SearchRequest
  ) async throws -> Mountain.SearchResult {
    var queryItems = [URLQueryItem(name: "page", value: "\(request.page)")]
    queryItems.append(
      URLQueryItem(
        name: "category",
        value: request.search.category == .planned ? "planned" : "recommended"
      )
    )
    if !request.search.text.isEmpty {
      queryItems.append(URLQueryItem(name: "text", value: request.search.text))
    }
    let (data, _) = try await self.perform(
      self.request(path: "/mountains", queryItems: queryItems)
    )
    return try JSONDecoder().decode(Mountain.SearchResult.self, from: data)
  }
}

// MARK: - Mountain Detail

extension CanIClimbAPI {
  public func mountain(with id: Mountain.ID) async throws -> Mountain? {
    let (data, resp) = try await self.perform(self.request(path: "/mountain/\(id)"))
    guard resp.statusCode != 404 else { return nil }
    return try JSONDecoder().decode(Mountain.self, from: data)
  }
}

// MARK: - Planned Climbs

extension CanIClimbAPI {
  public typealias PlannedClimbResponse = CachedPlannedClimbRecord

  public func plannedClimbs(
    for id: Mountain.ID
  ) async throws -> IdentifiedArrayOf<PlannedClimbResponse> {
    let (data, resp) = try await self.perform(
      self.request(path: "/mountain/\(id)/climbs")
    )
    guard resp.statusCode != 404 else { return [] }
    return try JSONDecoder().decode(IdentifiedArrayOf<PlannedClimbResponse>.self, from: data)
  }
}

// MARK: - Climb Planning

extension CanIClimbAPI {
  public struct PlanClimbRequest: Hashable, Sendable, Codable {
    public let mountainId: Mountain.ID
    public var targetDate: Date

    public init(create: Mountain.ClimbPlanCreate) {
      self.mountainId = create.mountainId
      self.targetDate = create.targetDate
    }
  }

  public func planClimb(_ request: PlanClimbRequest) async throws -> PlannedClimbResponse {
    let urlRequest = self.request(
      path: "/mountain/\(request.mountainId)/climbs",
      method: "POST",
      body: try JSONEncoder().encode(request)
    )
    let (data, _) = try await self.perform(urlRequest)
    return try JSONDecoder().decode(PlannedClimbResponse.self, from: data)
  }

  public struct UnplanClimbsError: Hashable, Error {
    public let statusCode: Int

    public init(statusCode: Int) {
      self.statusCode = statusCode
    }
  }

  public func unplanClimbs(ids: OrderedSet<Mountain.PlannedClimb.ID>) async throws {
    let queryItems = [
      URLQueryItem(name: "ids", value: ids.map(\.uuidString).joined(separator: ","))
    ]
    let request = self.request(
      path: "/mountain/climbs",
      method: "DELETE",
      queryItems: queryItems
    )
    let (_, resp) = try await self.perform(request)
    if resp.statusCode != 204 {
      throw UnplanClimbsError(statusCode: resp.statusCode)
    }
  }
}

// MARK: - Climb Achieving

extension CanIClimbAPI {
  public func achieveClimb(for id: Mountain.PlannedClimb.ID) async throws -> PlannedClimbResponse {
    try await self.achieveQueue.run {
      let request = self.request(path: "/mountain/climbs/\(id)/achieve", method: "POST")
      let (data, _) = try await self.perform(request)
      return try JSONDecoder().decode(PlannedClimbResponse.self, from: data)
    }
  }

  public func unachieveClimb(
    for id: Mountain.PlannedClimb.ID
  ) async throws -> PlannedClimbResponse {
    try await self.achieveQueue.run {
      let request = self.request(path: "/mountain/climbs/\(id)/unachieve", method: "POST")
      let (data, _) = try await self.perform(request)
      return try JSONDecoder().decode(PlannedClimbResponse.self, from: data)
    }
  }
}

// MARK: - Helper

extension CanIClimbAPI {
  private func perform(_ originalRequest: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (access, refresh) = await self.tokens.bearerValues
    let accessToken =
      if access == nil && refresh != nil {
        try await self.refreshAccessToken(refreshToken: refresh)
      } else {
        access
      }

    var request = originalRequest
    if let accessToken {
      request.setAuthorization(token: accessToken)
    }
    let (data, response) = try await self.send(request)
    guard response.statusCode == 401 else { return (data, response) }

    request.setAuthorization(token: try await self.refreshAccessToken(refreshToken: refresh))
    return try await self.send(request)
  }

  private func refreshAccessToken(refreshToken: String?) async throws -> String {
    try await withCurrentLogger(Logger(label: "caniclimb.api.refresh")) {
      let response = try await self.tokens.load(taskName: "refresh-access-token") {
        guard let refreshToken else { throw User.UnauthorizedError() }
        var request = self.request(path: "/auth/refresh", method: "POST")
        request.setAuthorization(token: refreshToken)
        let (data, resp) = try await self.send(request)
        guard resp.statusCode != 401 else { throw User.UnauthorizedError() }
        return try JSONDecoder().decode(Tokens.Response.self, from: data)
      }
      return response.accessToken
    }
  }

  private func request(
    path: String,
    method: String = "GET",
    queryItems: [URLQueryItem] = [URLQueryItem](),
    body: Data? = nil
  ) -> URLRequest {
    var url = self.baseURL
    url.append(path: path)
    if !queryItems.isEmpty {
      url.append(queryItems: queryItems)
    }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    return request
  }

  private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await self.transport.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw NonHTTPResponseError() }
    return (data, response)
  }
}

private struct NonHTTPResponseError: Error {}

extension URLRequest {
  fileprivate mutating func setAuthorization(token: String) {
    self.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
  }
}
