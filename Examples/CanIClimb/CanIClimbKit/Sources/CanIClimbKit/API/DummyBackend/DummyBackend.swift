import Foundation
import Logging
import OrderedCollections
import Tagged
import UUIDV7

// MARK: - DummyBackend

public final class DummyBackend: HTTPDataTransport {
  public typealias Response = HTTPDataResponse
  public typealias ResponseOverride =
    @Sendable (URLRequest) async throws -> Response?

  private let mountains: Mountains
  private let storage: UserData.Storage
  private let delay: @Sendable () async throws -> Void
  private let responseOverride: ResponseOverride

  private init(
    mountains: Mountains,
    storage: UserData.Storage,
    delay: @escaping @Sendable () async throws -> Void,
    responseOverride: @escaping ResponseOverride
  ) {
    self.mountains = mountains
    self.storage = storage
    self.delay = delay
    self.responseOverride = responseOverride
  }

  public convenience init() {
    self.init(
      mountains: Mountains(),
      storage: UserData.Storage(),
      delay: {
        try await Task.sleep(for: .seconds(Double.random(in: 0.1...3)))
      },
      responseOverride: { _ in nil }
    )
  }

  public convenience init(
    scenario: Scenario,
    responseOverride: @escaping ResponseOverride = { _ in nil }
  ) {
    self.init(
      mountains: Mountains(mountains: scenario.mountains),
      storage: UserData.Storage(data: UserData(scenario: scenario)),
      delay: {},
      responseOverride: responseOverride
    )
  }

  public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await self.delay()
    let response = try await self.response(for: request)
    return try response.result(for: request)
  }

  private func response(for request: URLRequest) async throws -> Response {
    if let response = try await self.responseOverride(request) {
      return response
    }
    return try await withCurrentLogger(Logger(label: "dummy.backend")) {
      guard let route = try Route(request: request) else {
        return Response(statusCode: 404)
      }
      return try await self.handle(route: route, request: request)
    }
  }

  private func handle(route: Route, request: URLRequest) async throws -> Response {
    switch route {
    case .achieveClimb(let id):
      guard request.isAuthenticated else { return Self.unauthorizedResponse }
      let climb = try await self.storage.achieveClimb(with: id)
      return Response.json(climb, statusCode: climb != nil ? 200 : 404)

    case .unachieveClimb(let id):
      guard request.isAuthenticated else { return Self.unauthorizedResponse }
      let climb = try await self.storage.unachieveClimb(with: id)
      return Response.json(climb, statusCode: climb != nil ? 200 : 404)

    case .currentUser:
      guard request.isAuthenticated, let user = await self.storage.currentUser else {
        return Self.unauthorizedResponse
      }
      return Response.json(user)

    case .deleteCurrentUser:
      guard request.isAuthenticated else { return Self.unauthorizedResponse }
      try await self.storage.deleteCurrentUser()
      return Response(statusCode: 204)

    case .editCurrentUser(let edit):
      guard request.isAuthenticated, let user = try await self.storage.editCurrentUser(with: edit)
      else { return Self.unauthorizedResponse }
      return Response.json(user)

    case .mountain(let id):
      guard let mountain = try await self.mountains.mountain(for: id) else {
        return Response(statusCode: 404)
      }
      return Response.json(mountain)

    case .searchMountains(let query):
      let plannedIds = await self.storage.plannedMountainIds
      let result = try await self.mountains.mountains(for: query, plannedIds: plannedIds)
      return Response.json(result)

    case .planClimb(let plan):
      guard request.isAuthenticated else { return Self.unauthorizedResponse }
      let climb = try await self.storage.planClimb(with: plan)
      return Response.json(climb, statusCode: 201)

    case .unplanClimbs(let ids):
      guard request.isAuthenticated else { return Self.unauthorizedResponse }
      try await self.storage.unplanClimbs(with: ids)
      return Response(statusCode: 204)

    case .plannedClimbs(let mountainId):
      guard request.isAuthenticated else { return Self.unauthorizedResponse }
      let climbs = try await self.storage.plannedClimbs(for: mountainId)
      return Response.json(climbs)

    case .refreshAccessToken:
      guard request.isAuthenticated else { return Self.unauthorizedResponse }
      return Response.json(
        CanIClimbAPI.Tokens.Response(accessToken: "access", refreshToken: nil)
      )

    case .signIn(let credentials):
      try await self.storage.signInUser(with: credentials)
      return Response.json(
        CanIClimbAPI.Tokens.Response(accessToken: "access", refreshToken: "refresh")
      )

    case .signOut:
      guard request.isAuthenticated else { return Self.unauthorizedResponse }
      try await self.storage.signOutCurrentUser()
      return Response(statusCode: 204)
    }
  }

  private static var unauthorizedResponse: Response {
    Response(statusCode: 401, body: .data(Data("{\"error\":\"Unauthorized\"}".utf8)))
  }
}

// MARK: - Scenario

extension DummyBackend {
  public struct Scenario: Hashable, Sendable {
    public var mountains: [Mountain]
    public var users: [User]
    public var currentUserId: User.ID?
    public var plannedClimbs: [CanIClimbAPI.PlannedClimbResponse]

    public init(
      mountains: [Mountain] = [Mountain](),
      users: [User] = [User](),
      currentUserId: User.ID? = nil,
      plannedClimbs: [CanIClimbAPI.PlannedClimbResponse] = [CanIClimbAPI.PlannedClimbResponse]()
    ) {
      self.mountains = mountains
      self.users = users
      self.currentUserId = currentUserId
      self.plannedClimbs = plannedClimbs
    }
  }
}

// MARK: - Route

extension DummyBackend {
  private enum Route {
    case refreshAccessToken
    case signIn(User.SignInCredentials)
    case signOut
    case currentUser
    case editCurrentUser(User.Edit)
    case deleteCurrentUser
    case searchMountains(Mountain.SearchRequest)
    case mountain(Mountain.ID)
    case plannedClimbs(Mountain.ID)
    case planClimb(CanIClimbAPI.PlanClimbRequest)
    case unplanClimbs(OrderedSet<Mountain.PlannedClimb.ID>)
    case achieveClimb(Mountain.PlannedClimb.ID)
    case unachieveClimb(Mountain.PlannedClimb.ID)

    init?(request: URLRequest) throws {
      let method = request.httpMethod ?? "GET"
      let path = request.url?.path() ?? ""

      switch (method, path) {
      case ("POST", "/auth/refresh"):
        self = .refreshAccessToken
      case ("POST", "/auth/sign-in"):
        self = .signIn(try request.decodeBody(as: User.SignInCredentials.self))
      case ("POST", "/auth/sign-out"):
        self = .signOut
      case ("GET", "/user"):
        self = .currentUser
      case ("PATCH", "/user"):
        self = .editCurrentUser(try request.decodeBody(as: User.Edit.self))
      case ("DELETE", "/user"):
        self = .deleteCurrentUser
      case ("GET", "/mountains"):
        self = .searchMountains(try request.mountainSearchRequest())
      case ("DELETE", "/mountain/climbs"):
        self = .unplanClimbs(try request.plannedClimbIds())
      default:
        guard let route = try Self.dynamicRoute(method: method, path: path, request: request)
        else { return nil }
        self = route
      }
    }

    private static func dynamicRoute(
      method: String,
      path: String,
      request: URLRequest
    ) throws -> Self? {
      let components = path.split(separator: "/").map(String.init)

      if components.count == 2,
        components[0] == "mountain",
        method == "GET",
        let id = Mountain.ID(uuidString: components[1])
      {
        return .mountain(id)
      }
      if components.count == 3,
        components[0] == "mountain",
        components[2] == "climbs",
        let id = Mountain.ID(uuidString: components[1])
      {
        switch method {
        case "GET": return .plannedClimbs(id)
        case "POST":
          return .planClimb(try request.decodeBody(as: CanIClimbAPI.PlanClimbRequest.self))
        default: return nil
        }
      }
      if components.count == 4,
        components[0] == "mountain",
        components[1] == "climbs",
        method == "POST",
        let id = Mountain.PlannedClimb.ID(uuidString: components[2])
      {
        switch components[3] {
        case "achieve": return .achieveClimb(id)
        case "unachieve": return .unachieveClimb(id)
        default: return nil
        }
      }
      return nil
    }
  }
}

// MARK: - Request Helpers

extension URLRequest {
  fileprivate var isAuthenticated: Bool {
    self.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true
  }

  fileprivate func decodeBody<Value: Decodable>(as type: Value.Type) throws -> Value {
    try JSONDecoder().decode(type, from: self.httpBody ?? Data())
  }

  fileprivate func mountainSearchRequest() throws -> Mountain.SearchRequest {
    guard let url = self.url else { throw InvalidRequestError() }
    let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    let values = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
    guard let page = values["page"].flatMap(Int.init) else { throw InvalidRequestError() }
    let category: Mountain.Search.Category =
      switch values["category"] {
      case "recommended": .recommended
      case "planned": .planned
      default: throw InvalidRequestError()
      }
    return Mountain.SearchRequest(
      search: Mountain.Search(text: values["text"] ?? "", category: category),
      page: page
    )
  }

  fileprivate func plannedClimbIds() throws -> OrderedSet<Mountain.PlannedClimb.ID> {
    guard let url = self.url else { throw InvalidRequestError() }
    let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    guard let value = queryItems.first(where: { $0.name == "ids" })?.value else {
      throw InvalidRequestError()
    }
    let components = value.split(separator: ",")
    let ids = components.compactMap { Mountain.PlannedClimb.ID(uuidString: String($0)) }
    guard ids.count == components.count else { throw InvalidRequestError() }
    return OrderedSet(ids)
  }
}

private struct InvalidRequestError: Error {}
