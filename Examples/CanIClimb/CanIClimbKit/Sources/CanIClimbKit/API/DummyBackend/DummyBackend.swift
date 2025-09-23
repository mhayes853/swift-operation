import Foundation

// MARK: - DummyBackend

public final class DummyBackend: CanIClimbAPI.DataTransport {
  private let storage = UserData.Storage()

  public init() {}

  public func send(
    request: CanIClimbAPI.Request,
    in context: CanIClimbAPI.Request.Context
  ) async throws -> (Data, HTTPURLResponse) {
    try await self.randomDelay()
    switch request {
    case .achieveClimb(let id):
      guard context.isAuthenticated else {
        return (Data(), HTTPURLResponse(context: context, statusCode: 401))
      }
      let climb = try await self.storage.achieveClimb(with: id)
      return (
        try JSONEncoder().encode(climb),
        HTTPURLResponse(context: context, statusCode: climb != nil ? 200 : 404)
      )

    case .unachieveClimb(let id):
      guard context.isAuthenticated else {
        return (Data(), HTTPURLResponse(context: context, statusCode: 401))
      }
      let climb = try await self.storage.unachieveClimb(with: id)
      return (
        try JSONEncoder().encode(climb),
        HTTPURLResponse(context: context, statusCode: climb != nil ? 200 : 404)
      )

    case .currentUser:
      guard context.isAuthenticated, let user = await self.storage.currentUser else {
        return (Data(), HTTPURLResponse(context: context, statusCode: 401))
      }
      return (try JSONEncoder().encode(user), HTTPURLResponse(context: context, statusCode: 200))

    case .deleteCurrentUser:
      guard context.isAuthenticated else {
        return (Data(), HTTPURLResponse(context: context, statusCode: 401))
      }
      try await self.storage.deleteCurrentUser()
      return (Data(), HTTPURLResponse(context: context, statusCode: 204))

    case .editCurrentUser(let edit):
      guard context.isAuthenticated, let user = try await self.storage.editCurrentUser(with: edit)
      else {
        return (Data(), HTTPURLResponse(context: context, statusCode: 401))
      }
      return (try JSONEncoder().encode(user), HTTPURLResponse(context: context, statusCode: 200))

    case .mountain(let id):
      return (Data(), HTTPURLResponse(context: context, statusCode: 404))

    case .searchMountains(let query):
      let result = Mountain.SearchResult(mountains: [], hasNextPage: false)
      return (try JSONEncoder().encode(result), HTTPURLResponse(context: context, statusCode: 200))

    case .planClimb(let request):
      guard context.isAuthenticated else {
        return (Data(), HTTPURLResponse(context: context, statusCode: 401))
      }
      let climb = try await self.storage.planClimb(with: request)
      return (try JSONEncoder().encode(climb), HTTPURLResponse(context: context, statusCode: 201))

    case .unplanClimbs(let ids):
      guard context.isAuthenticated else {
        return (Data(), HTTPURLResponse(context: context, statusCode: 401))
      }
      try await self.storage.unplanClimbs(with: ids)
      return (Data(), HTTPURLResponse(context: context, statusCode: 204))

    case .plannedClimbs(let mountainId):
      guard context.isAuthenticated else {
        return (Data(), HTTPURLResponse(context: context, statusCode: 401))
      }
      let climbs = try await self.storage.plannedClimbs(for: mountainId)
      return (try JSONEncoder().encode(climbs), HTTPURLResponse(context: context, statusCode: 200))

    case .refreshAccessToken:
      guard context.refreshToken != nil else {
        return (Data(), HTTPURLResponse(context: context, statusCode: 401))
      }
      let tokens = CanIClimbAPI.Tokens.Response(accessToken: "access", refreshToken: nil)
      return (try JSONEncoder().encode(tokens), HTTPURLResponse(context: context, statusCode: 200))

    case .signIn(let credentials):
      try await self.storage.signInUser(with: credentials)
      let tokens = CanIClimbAPI.Tokens.Response(accessToken: "access", refreshToken: "refresh")
      return (try JSONEncoder().encode(tokens), HTTPURLResponse(context: context, statusCode: 200))

    case .signOut:
      guard context.isAuthenticated else {
        return (Data(), HTTPURLResponse(context: context, statusCode: 401))
      }
      try await self.storage.signOutCurrentUser()
      return (Data(), HTTPURLResponse(context: context, statusCode: 204))
    }
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
