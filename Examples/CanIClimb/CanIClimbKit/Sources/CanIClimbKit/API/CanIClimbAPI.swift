import Foundation
import IssueReporting
import OrderedCollections
import Query
import Tagged
import UUIDV7

// MARK: - CanIClimbAPI

public final class CanIClimbAPI: Sendable {
  private let baseURL: URL
  private let transport: any DataTransport
  private let tokens: Tokens
  private let achieveQueue = SerialTaskQueue(priority: .userInitiated)

  public init(
    baseURL: URL = .canIClimbAPIBase,
    transport: any DataTransport,
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
    try await self.tokens.load {
      let (data, _) = try await self.perform(request: .signIn(credentials))
      return try JSONDecoder().decode(Tokens.Response.self, from: data)
    }
  }

  public func signOut() async throws {
    let (_, resp) = try await self.perform(request: .signOut)
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
    let (data, _) = try await self.perform(request: .currentUser)
    return try JSONDecoder().decode(User.self, from: data)
  }
}

// MARK: - Edit User

extension CanIClimbAPI {
  public func editUser(with edit: User.Edit) async throws -> User {
    let (data, _) = try await self.perform(request: .editCurrentUser(edit))
    return try JSONDecoder().decode(User.self, from: data)
  }
}

// MARK: - Delete User

extension CanIClimbAPI {
  public func deleteUser() async throws {
    let (_, resp) = try await self.perform(request: .deleteCurrentUser)
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
    let (data, _) = try await self.perform(request: .searchMountains(request))
    return try JSONDecoder().decode(Mountain.SearchResult.self, from: data)
  }
}

// MARK: - Mountain Detail

extension CanIClimbAPI {
  public func mountain(with id: Mountain.ID) async throws -> Mountain? {
    let (data, resp) = try await self.perform(request: .mountain(id))
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
    let (data, resp) = try await self.perform(request: .plannedClimbs(id))
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
    let (data, _) = try await self.perform(request: .planClimb(request))
    return try JSONDecoder().decode(PlannedClimbResponse.self, from: data)
  }

  public struct UnplanClimbsError: Hashable, Error {
    public let statusCode: Int

    public init(statusCode: Int) {
      self.statusCode = statusCode
    }
  }

  public func unplanClimbs(ids: OrderedSet<Mountain.PlannedClimb.ID>) async throws {
    let (_, resp) = try await self.perform(request: .unplanClimbs(ids))
    if resp.statusCode != 204 {
      throw UnplanClimbsError(statusCode: resp.statusCode)
    }
  }
}

// MARK: - Climb Achieving

extension CanIClimbAPI {
  public func achieveClimb(for id: Mountain.PlannedClimb.ID) async throws -> PlannedClimbResponse {
    try await self.achieveQueue.run {
      let (data, _) = try await self.perform(request: .achieveClimb(id))
      return try JSONDecoder().decode(PlannedClimbResponse.self, from: data)
    }
  }

  public func unachieveClimb(
    for id: Mountain.PlannedClimb.ID
  ) async throws -> PlannedClimbResponse {
    try await self.achieveQueue.run {
      let (data, _) = try await self.perform(request: .unachieveClimb(id))
      return try JSONDecoder().decode(PlannedClimbResponse.self, from: data)
    }
  }
}

// MARK: - Helper

extension CanIClimbAPI {
  private func perform(request: Request) async throws -> (Data, HTTPURLResponse) {
    let (access, refresh) = await self.tokens.bearerValues
    var requestContext = Request.Context(
      baseURL: self.baseURL,
      accessToken: access,
      refreshToken: refresh
    )
    if requestContext.accessToken == nil && requestContext.refreshToken != nil {
      requestContext.accessToken = try await self.refreshAccessToken(in: requestContext)
    }
    let (data, response) = try await self.transport.send(request: request, in: requestContext)
    guard response.statusCode == 401 else { return (data, response) }

    requestContext.accessToken = try await self.refreshAccessToken(in: requestContext)
    return try await self.transport.send(request: request, in: requestContext)
  }

  private func refreshAccessToken(in context: Request.Context) async throws -> String {
    let response = try await self.tokens.load {
      let (data, _) = try await self.transport.send(request: .refreshAccessToken, in: context)
      return try JSONDecoder().decode(Tokens.Response.self, from: data)
    }
    return response.accessToken
  }
}
