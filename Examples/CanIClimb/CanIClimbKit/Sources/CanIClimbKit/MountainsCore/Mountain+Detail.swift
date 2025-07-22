import Dependencies
import SharingQuery

// MARK: - Loader

extension Mountain {
  public protocol Loader: Sendable {
    func mountain(with id: Mountain.ID) async throws -> Mountain?
  }

  public enum LoaderKey: DependencyKey {
    public static let liveValue: any Loader = CanIClimbAPI.shared
  }
}

extension CanIClimbAPI: Mountain.Loader {}

// MARK: - Query

extension Mountain {
  public static func query(id: Mountain.ID) -> some QueryRequest<Self, Query.State> {
    Query(id: id)
  }

  public struct Query: QueryRequest {
    let id: Mountain.ID

    public var path: QueryPath {
      .mountain(with: self.id)
    }

    public func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<Mountain?>
    ) async throws -> Mountain? {
      @Dependency(Mountain.LoaderKey.self) var loader
      return try await loader.mountain(with: id)
    }
  }
}

extension QueryPath {
  public static let mountain = Self("mountain")

  public static func mountain(with id: Mountain.ID) -> Self {
    .mountain.appending(id)
  }
}
