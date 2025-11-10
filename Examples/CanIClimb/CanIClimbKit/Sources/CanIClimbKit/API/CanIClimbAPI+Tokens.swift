import Foundation
import Operation

// MARK: - Tokens

extension CanIClimbAPI {
  public final actor Tokens {
    private let secureStorage: any SecureStorage
    private let refreshTokenKey: String
    private let store: OperationStore<
      MutationState<Response.LoadArguments, Response, any Error>
    >

    public init(
      client: OperationClient,
      secureStorage: any SecureStorage,
      refreshTokenKey: String = "canIClimbAPI_RefreshToken"
    ) {
      self.secureStorage = secureStorage
      self.refreshTokenKey = refreshTokenKey
      self.store = client.store(for: Response.mutation)
    }
  }
}

// MARK: - Response

extension CanIClimbAPI.Tokens {
  public struct Response: Codable, Hashable, Sendable {
    public let accessToken: String
    public let refreshToken: String?

    public init(accessToken: String, refreshToken: String?) {
      self.accessToken = accessToken
      self.refreshToken = refreshToken
    }
  }
}

// MARK: - Bearer Values

extension CanIClimbAPI.Tokens {
  public var bearerValues: (access: String?, refresh: String?) {
    (
      access: self.store.currentValue?.accessToken,
      refresh: self.secureStorage[self.refreshTokenKey]
        .map { String(decoding: $0, as: UTF8.self) }
    )
  }
}

// MARK: - Load Tokens

extension CanIClimbAPI.Tokens {
  @discardableResult
  public func load(
    taskName: String,
    using loader: @escaping @Sendable () async throws -> CanIClimbAPI.Tokens.Response
  ) async throws -> CanIClimbAPI.Tokens.Response {
    currentLogger.info("Requesting Tokens", metadata: ["task.name": .string(taskName)])

    var context = self.store.context
    context.operationTaskConfiguration.name = taskName

    let response = try await self.store.mutate(
      with: Response.LoadArguments(load: loader),
      using: context
    )
    if let refreshToken = response.refreshToken {
      self.secureStorage[self.refreshTokenKey] = Data(refreshToken.utf8)
    }
    return response
  }
}

// MARK: - Clear Tokens

extension CanIClimbAPI.Tokens {
  public func clear() {
    self.secureStorage[self.refreshTokenKey] = nil
    self.store.resetState()
  }
}

// MARK: - Mutation

extension CanIClimbAPI.Tokens.Response {
  fileprivate struct LoadArguments: Sendable {
    let load: @Sendable () async throws -> CanIClimbAPI.Tokens.Response
  }

  fileprivate static var mutation:
    some MutationRequest<LoadArguments, CanIClimbAPI.Tokens.Response, any Error>
  {
    Self.$mutation.maxHistory(length: 1).deduplicated()
  }

  @MutationRequest
  private static func mutation(arguments: LoadArguments) async throws -> CanIClimbAPI.Tokens.Response {
    try await arguments.load()
  }
}
