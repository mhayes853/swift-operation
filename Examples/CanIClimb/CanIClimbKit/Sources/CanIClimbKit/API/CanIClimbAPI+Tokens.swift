import Foundation
import Operation

// MARK: - Tokens

extension CanIClimbAPI {
  public final actor Tokens {
    private let secureStorage: any SecureStorage
    private let refreshTokenKey: String
    private let store: OperationStore<Response.Mutation.State>

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
    using loader: @escaping @Sendable () async throws -> CanIClimbAPI.Tokens.Response
  ) async throws -> CanIClimbAPI.Tokens.Response {
    let response = try await self.store.mutate(with: loader)
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
  // NB: Use a query store to control fetches to the access token to prevent duplicate concurrent
  // requests from either signing the user in, or refreshing the access token. This also adds
  // automatic retries and exponential backoff.
  //
  // Additionally, we'll ensure that the store that powers the mutation is never evicted from the
  // query cache by using the `evictWhen` modifier in conjunction with an empty set of evictable
  // memory pressures.
  fileprivate static let mutation = Mutation()
    .maxHistory(length: 1)
    .deduplicated()
    .evictWhen(pressure: [])

  fileprivate struct Mutation: MutationRequest, Hashable {
    typealias Arguments = @Sendable () async throws -> CanIClimbAPI.Tokens.Response

    func mutate(
      with arguments: @Sendable () async throws -> CanIClimbAPI.Tokens.Response,
      in context: OperationContext,
      with continuation: OperationContinuation<CanIClimbAPI.Tokens.Response>
    ) async throws -> CanIClimbAPI.Tokens.Response {
      try await arguments()
    }
  }
}
