import Dependencies
import Foundation
import SQLiteData
import SharingOperation
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
  public static func query(id: Mountain.ID) -> some QueryRequest<Self?, any Error> {
    Query(id: id).stale(after: TimeInterval(duration: .fiveMinutes))
  }

  public struct Query: QueryRequest, Sendable {
    let id: Mountain.ID

    public var path: OperationPath {
      .mountain(with: self.id)
    }

    public func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<Mountain?, any Error>
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

extension OperationPath {
  public static let mountain = Self("mountain")

  public static func mountain(with id: Mountain.ID) -> Self {
    .mountain.appending(id)
  }
}
