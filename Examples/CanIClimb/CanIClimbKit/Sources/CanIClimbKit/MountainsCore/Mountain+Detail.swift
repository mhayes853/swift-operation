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

      let localMountain = try await database.read { db in
        try CachedMountainRecord.find(#bind(self.id)).fetchOne(db)
      }
      if let localMountain {
        continuation.yield(Mountain(cached: localMountain))
      }
      guard let mountain = try await loader.mountain(with: self.id) else {
        try await database.write { db in
          try CachedMountainRecord.delete().where { $0.id == #bind(self.id) }.execute(db)
        }
        return nil
      }
      try await database.write { db in
        try CachedMountainRecord.upsert {
          CachedMountainRecord.Draft(CachedMountainRecord(mountain: mountain))
        }
        .execute(db)
      }
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
