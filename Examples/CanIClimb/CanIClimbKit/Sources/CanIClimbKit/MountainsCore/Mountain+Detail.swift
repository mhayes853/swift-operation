import Dependencies
import SharingGRDB
import SharingQuery
import StructuredQueries

// MARK: - Loader

extension Mountain {
  public protocol Loader: Sendable {
    func mountain(with id: Mountain.ID) async throws -> Mountain?
  }

  public enum LoaderKey: DependencyKey {
    public static let liveValue: any Loader = CanIClimbAPI.shared
  }
}

extension Mountain {
  @MainActor
  public final class MockLoader: Loader {
    public var result: Result<Mountain?, any Error>

    public init(result: Result<Mountain?, any Error>) {
      self.result = result
    }

    public func mountain(with id: Mountain.ID) async throws -> Mountain? {
      try self.result.get()
    }
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
      @Dependency(\.defaultDatabase) var database

      async let mountain = loader.mountain(with: self.id)
      let localMountain = try await database.read { try Mountain.find(by: self.id, in: $0) }
      if let localMountain {
        continuation.yield(localMountain)
      }
      guard let mountain = try await mountain else {
        try await database.write { try Mountain.delete(by: self.id, in: $0) }
        return nil
      }
      try await database.write { try Mountain.save(CollectionOfOne(mountain), in: $0) }
      return mountain
    }
  }
}

extension QueryPath {
  public static let mountain = Self("mountain")

  public static func mountain(with id: Mountain.ID) -> Self {
    .mountain.appending(id)
  }
}
