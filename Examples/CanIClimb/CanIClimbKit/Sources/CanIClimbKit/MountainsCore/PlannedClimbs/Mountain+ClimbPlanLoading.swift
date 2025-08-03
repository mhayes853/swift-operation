import Dependencies
import Query
import Tagged
import UUIDV7

// MARK: - PlannedClimbsLoader

extension Mountain {
  public protocol PlannedClimbsLoader: Sendable {
    func localPlannedClimbs(for id: Mountain.ID) async throws -> IdentifiedArrayOf<PlannedClimb>
    func plannedClimbs(for id: Mountain.ID) async throws -> IdentifiedArrayOf<PlannedClimb>
  }

  public enum PlannedClimbsLoaderKey: DependencyKey {
    public static var liveValue: any PlannedClimbsLoader {
      fatalError()
    }
  }
}

extension Mountain {
  @MainActor
  public final class MockPlannedClimbsLoader: PlannedClimbsLoader {
    public var results = [Mountain.ID: Result<IdentifiedArrayOf<PlannedClimb>, any Error>]()

    public nonisolated init() {}

    public func localPlannedClimbs(
      for id: Mountain.ID
    ) async throws -> IdentifiedArrayOf<PlannedClimb> {
      []
    }

    public func plannedClimbs(for id: Mountain.ID) async throws -> IdentifiedArrayOf<PlannedClimb> {
      guard let result = results[id] else { throw NoResultError() }
      return try result.get()
    }

    private struct NoResultError: Error {}
  }
}

// MARK: - Query

extension Mountain {
  public static func plannedClimbsQuery(
    for id: Mountain.ID
  ) -> some QueryRequest<IdentifiedArrayOf<PlannedClimb>, PlannedClimbsQuery.State> {
    PlannedClimbsQuery(id: id)
  }

  public struct PlannedClimbsQuery: QueryRequest {
    let id: Mountain.ID

    public var path: QueryPath {
      .mountainPlannedClimbs.appending(id)
    }

    public func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<IdentifiedArrayOf<PlannedClimb>>
    ) async throws -> IdentifiedArrayOf<PlannedClimb> {
      @Dependency(Mountain.PlannedClimbsLoaderKey.self) var loader
      continuation.yield(try await loader.localPlannedClimbs(for: self.id))
      return try await loader.plannedClimbs(for: self.id)
    }
  }
}

extension QueryPath {
  public static let mountainPlannedClimbs = Self("mountain-planned-climbs")
}
