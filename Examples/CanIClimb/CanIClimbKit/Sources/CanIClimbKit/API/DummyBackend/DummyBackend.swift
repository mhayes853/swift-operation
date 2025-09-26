import Foundation
import Logging

// MARK: - DummyBackend

public final class DummyBackend: CanIClimbAPI.DataTransport {
  private let mountains = Mountains()
  private let storage = UserData.Storage()

  public init() {}

  public func send(
    request: CanIClimbAPI.Request,
    in context: CanIClimbAPI.Request.Context
  ) async throws -> (Data, HTTPURLResponse) {
    try await self.randomDelay()
    return try await withCurrentLogger(Logger(label: "dummy.backend")) {
      try await self.handle(request: request, in: context)
    }
  }

  private func handle(
    request: CanIClimbAPI.Request,
    in context: CanIClimbAPI.Request.Context
  ) async throws -> (Data, HTTPURLResponse) {
    switch request {
    case .achieveClimb(let id):
      guard context.isAuthenticated else { return self.unauthorizedResponse(in: context) }
      let climb = try await self.storage.achieveClimb(with: id)
      return (
        try JSONEncoder().encode(climb),
        HTTPURLResponse(context: context, statusCode: climb != nil ? 200 : 404)
      )

    case .unachieveClimb(let id):
      guard context.isAuthenticated else { return self.unauthorizedResponse(in: context) }
      let climb = try await self.storage.unachieveClimb(with: id)
      return (
        try JSONEncoder().encode(climb),
        HTTPURLResponse(context: context, statusCode: climb != nil ? 200 : 404)
      )

    case .currentUser:
      guard context.isAuthenticated, let user = await self.storage.currentUser else {
        return self.unauthorizedResponse(in: context)
      }
      return (try JSONEncoder().encode(user), HTTPURLResponse(context: context, statusCode: 200))

    case .deleteCurrentUser:
      guard context.isAuthenticated else { return self.unauthorizedResponse(in: context) }
      try await self.storage.deleteCurrentUser()
      return (Data(), HTTPURLResponse(context: context, statusCode: 204))

    case .editCurrentUser(let edit):
      guard context.isAuthenticated, let user = try await self.storage.editCurrentUser(with: edit)
      else { return self.unauthorizedResponse(in: context) }
      return (try JSONEncoder().encode(user), HTTPURLResponse(context: context, statusCode: 200))

    case .mountain(let id):
      guard let mountain = try await self.mountains.mountain(for: id) else {
        return (Data(), HTTPURLResponse(context: context, statusCode: 404))
      }
      return (
        try JSONEncoder().encode(mountain), HTTPURLResponse(context: context, statusCode: 200)
      )

    case .searchMountains(let query):
      let plannedIds = await self.storage.plannedMountainIds
      let result = try await self.mountains.mountains(for: query, plannedIds: plannedIds)
      return (try JSONEncoder().encode(result), HTTPURLResponse(context: context, statusCode: 200))

    case .planClimb(let request):
      guard context.isAuthenticated else { return self.unauthorizedResponse(in: context) }
      let climb = try await self.storage.planClimb(with: request)
      return (try JSONEncoder().encode(climb), HTTPURLResponse(context: context, statusCode: 201))

    case .unplanClimbs(let ids):
      guard context.isAuthenticated else { return self.unauthorizedResponse(in: context) }
      try await self.storage.unplanClimbs(with: ids)
      return (Data(), HTTPURLResponse(context: context, statusCode: 204))

    case .plannedClimbs(let mountainId):
      guard context.isAuthenticated else { return self.unauthorizedResponse(in: context) }
      let climbs = try await self.storage.plannedClimbs(for: mountainId)
      return (try JSONEncoder().encode(climbs), HTTPURLResponse(context: context, statusCode: 200))

    case .refreshAccessToken:
      guard context.refreshToken != nil else { return self.unauthorizedResponse(in: context) }
      let tokens = CanIClimbAPI.Tokens.Response(accessToken: "access", refreshToken: nil)
      return (try JSONEncoder().encode(tokens), HTTPURLResponse(context: context, statusCode: 200))

    case .signIn(let credentials):
      try await self.storage.signInUser(with: credentials)
      let tokens = CanIClimbAPI.Tokens.Response(accessToken: "access", refreshToken: "refresh")
      return (try JSONEncoder().encode(tokens), HTTPURLResponse(context: context, statusCode: 200))

    case .signOut:
      guard context.isAuthenticated else { return self.unauthorizedResponse(in: context) }
      try await self.storage.signOutCurrentUser()
      return (Data(), HTTPURLResponse(context: context, statusCode: 204))
    }
  }

  private func unauthorizedResponse(
    in context: CanIClimbAPI.Request.Context
  ) -> (Data, HTTPURLResponse) {
    (Data("{\"error\":\"Unauthorized\"}".utf8), HTTPURLResponse(context: context, statusCode: 401))
  }

  private func randomDelay() async throws {
    try await Task.sleep(for: .seconds(Double.random(in: 0.1...3.0)))
  }
}

// MARK: - Helpers

extension HTTPURLResponse {
  fileprivate convenience init(context: CanIClimbAPI.Request.Context, statusCode: Int) {
    self.init(url: context.baseURL, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
  }
}

extension CanIClimbAPI.Request.Context {
  fileprivate var isAuthenticated: Bool {
    self.accessToken != nil
  }
}
