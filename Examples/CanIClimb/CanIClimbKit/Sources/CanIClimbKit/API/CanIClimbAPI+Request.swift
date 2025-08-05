import Foundation
import OrderedCollections
import Tagged
import UUIDV7

// MARK: - Request

extension CanIClimbAPI {
  public enum Request: Equatable, Sendable {
    case refreshAccessToken
    case signIn(User.SignInCredentials)
    case signOut

    case currentUser
    case editCurrentUser(User.Edit)
    case deleteCurrentUser

    case searchMountains(Mountain.SearchRequest)
    case mountain(Mountain.ID)

    case plannedClimbs(Mountain.ID)
    case planClimb(PlanClimbRequest)
    case unplanClimbs(OrderedSet<Mountain.PlannedClimb.ID>)
  }
}

// MARK: - Context

extension CanIClimbAPI.Request {
  public struct Context: Sendable {
    public let baseURL: URL
    public var accessToken: String?
    public var refreshToken: String?
  }
}

// MARK: - URLRequest

extension CanIClimbAPI.Request {
  public func urlRequest(in context: Context) throws -> URLRequest {
    var request = URLRequest(url: context.baseURL)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let accessToken = context.accessToken {
      request.setAuthorization(token: accessToken)
    }

    switch self {
    case .currentUser:
      self.makeCurrentUserRequest(&request)
    case .deleteCurrentUser:
      self.makeDeleteCurrentUserRequest(&request)
    case .editCurrentUser(let edit):
      try self.makeEditCurrentUserRequest(&request, with: edit)
    case .mountain(let id):
      self.makeMountainRequest(&request, for: id)
    case .refreshAccessToken:
      try self.makeRefreshAccessTokenRequest(&request, in: context)
    case .searchMountains(let searchRequest):
      self.makeSearchMountainsRequest(&request, with: searchRequest)
    case .signIn(let credentials):
      try self.makeSignInRequest(&request, with: credentials)
    case .signOut:
      self.makeSignOutRequest(&request)
    case .planClimb(let planRequest):
      try self.makePlanClimbRequest(&request, request: planRequest)
    case .plannedClimbs(let id):
      self.makeMountainPlannedClimbsRequest(&request, for: id)
    case .unplanClimbs(let ids):
      self.makeUnplanClimbRequest(&request, for: ids)
    }

    return request
  }

  private func makeRefreshAccessTokenRequest(
    _ request: inout URLRequest,
    in context: Context
  ) throws {
    request.url?.append(path: "/auth/refresh")
    request.httpMethod = "POST"
    guard let refreshToken = context.refreshToken else { throw User.UnauthorizedError() }
    request.setAuthorization(token: refreshToken)
  }

  private func makeSignInRequest(
    _ request: inout URLRequest,
    with credentials: User.SignInCredentials
  ) throws {
    request.url?.append(path: "/auth/sign-in")
    request.httpMethod = "POST"
    request.httpBody = try JSONEncoder().encode(credentials)
  }

  private func makeSignOutRequest(_ request: inout URLRequest) {
    request.url?.append(path: "/auth/sign-out")
    request.httpMethod = "POST"
  }

  private func makeCurrentUserRequest(_ request: inout URLRequest) {
    request.url?.append(path: "/user")
  }

  private func makeEditCurrentUserRequest(
    _ request: inout URLRequest,
    with edit: User.Edit
  ) throws {
    request.url?.append(path: "/user")
    request.httpMethod = "PATCH"
    request.httpBody = try JSONEncoder().encode(edit)
  }

  private func makeDeleteCurrentUserRequest(_ request: inout URLRequest) {
    request.url?.append(path: "/user")
    request.httpMethod = "DELETE"
  }

  private func makeSearchMountainsRequest(
    _ urlRequest: inout URLRequest,
    with request: Mountain.SearchRequest
  ) {
    urlRequest.url?.append(path: "/mountains")
    var queryItems = [URLQueryItem(name: "page", value: "\(request.page)")]
    switch request.search.category {
    case .planned: queryItems.append(URLQueryItem(name: "category", value: "planned"))
    case .recommended: queryItems.append(URLQueryItem(name: "category", value: "recommended"))
    }
    if !request.search.text.isEmpty {
      queryItems.append(URLQueryItem(name: "text", value: request.search.text))
    }
    urlRequest.url?.append(queryItems: queryItems)
  }

  private func makeMountainRequest(_ request: inout URLRequest, for id: Mountain.ID) {
    request.url?.append(path: "/mountain/\(id)")
  }

  private func makePlanClimbRequest(
    _ urlRequest: inout URLRequest,
    request: CanIClimbAPI.PlanClimbRequest
  ) throws {
    urlRequest.url?.append(path: "/mountain/\(request.mountainId)/climbs")
    urlRequest.httpMethod = "POST"
    urlRequest.httpBody = try JSONEncoder().encode(request)
  }

  private func makeMountainPlannedClimbsRequest(_ request: inout URLRequest, for id: Mountain.ID) {
    request.url?.append(path: "/mountain/\(id)/climbs")
  }

  private func makeUnplanClimbRequest(
    _ request: inout URLRequest,
    for ids: OrderedSet<Mountain.PlannedClimb.ID>
  ) {
    request.url?.append(path: "/mountain/climbs")
    request.url?
      .append(queryItems: [
        URLQueryItem(name: "ids", value: ids.map(\.uuidString).joined(separator: ","))
      ])
    request.httpMethod = "DELETE"
  }
}

// MARK: - Helper

extension URLRequest {
  fileprivate mutating func setAuthorization(token: String) {
    self.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
  }
}
