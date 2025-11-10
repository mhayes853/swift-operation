import CloudKit
import Dependencies
import Operation

// MARK: - Query

extension CKAccountStatus {
  public static var currentQuery: some QueryRequest<CKAccountStatus, any Error> {
    Self.$currentQuery.staleWhenNoValue().refetchOnPost(of: .CKAccountChanged)
  }

  @QueryRequest
  private static func currentQuery() async throws -> CKAccountStatus {
    @Dependency(CKAccountStatus.LoaderKey.self) var loader
    return try await loader.accountStatus()
  }
}

// MARK: - Loader

extension CKAccountStatus {
  public protocol Loader: Sendable {
    func accountStatus() async throws -> CKAccountStatus
  }

  public enum LoaderKey: DependencyKey {
    public static let liveValue: any Loader = CKContainer.canIClimb
  }
}

extension CKContainer: CKAccountStatus.Loader {}

extension CKAccountStatus {
  public struct MockLoader: Loader {
    public let status: @Sendable () async throws -> CKAccountStatus

    public init(status: @escaping @Sendable () async throws -> CKAccountStatus) {
      self.status = status
    }

    public func accountStatus() async throws -> CKAccountStatus {
      try await self.status()
    }
  }
}
