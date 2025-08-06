import Dependencies
import Foundation
import SharingGRDB
import SharingQuery
import StructuredQueries

// MARK: - Loader

extension Mountain {
  public protocol Loader: Sendable {
    func localMountain(with id: Mountain.ID) async throws -> Mountain?
    func mountain(with id: Mountain.ID) async throws -> Mountain?
  }

  public enum LoaderKey: DependencyKey {
    public static var liveValue: any Loader {
      Mountains.shared
    }
  }
}

extension Mountain {
  @MainActor
  public final class MockLoader: Loader {
    public var result: Result<Mountain?, any Error>
    public var localResult: Mountain?

    public init(result: Result<Mountain?, any Error>) {
      self.result = result
    }

    public func localMountain(with id: Mountain.ID) async throws -> Mountain? {
      self.localResult
    }

    public func mountain(with id: Mountain.ID) async throws -> Mountain? {
      try self.result.get()
    }
  }
}

// MARK: - Query

extension Mountain {
  public static func query(id: Mountain.ID) -> some QueryRequest<Self, Query.State> {
    Query(id: id).stale(after: TimeInterval(duration: .fiveMinutes))
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
      let loader = Dependency(Mountain.LoaderKey.self).wrappedValue

      async let mountain = loader.mountain(with: self.id)
      if let localMountain = try await loader.localMountain(with: self.id) {
        continuation.yield(localMountain)
      }
      return try await mountain
    }
  }
}

extension QueryPath {
  public static let mountain = Self("mountain")

  public static func mountain(with id: Mountain.ID) -> Self {
    .mountain.appending(id)
  }
}
