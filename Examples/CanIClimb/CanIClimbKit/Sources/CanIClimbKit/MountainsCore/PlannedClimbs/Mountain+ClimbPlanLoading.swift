import Dependencies
import Operation
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
      PlannedMountainClimbs.shared
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
  ) -> some QueryRequest<IdentifiedArrayOf<PlannedClimb>, any Error> {
    PlannedClimbsQuery(id: id)
  }

  public struct PlannedClimbsQuery: QueryRequest {
    let id: Mountain.ID

    public var path: OperationPath {
      .mountainPlannedClimbs.appending(id)
    }

    public func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<IdentifiedArrayOf<PlannedClimb>, any Error>
    ) async throws -> IdentifiedArrayOf<PlannedClimb> {
      @Dependency(Mountain.PlannedClimbsLoaderKey.self) var loader
      continuation.yield(try await loader.localPlannedClimbs(for: self.id))
      return try await loader.plannedClimbs(for: self.id)
    }
  }
}

extension OperationPath {
  public static let mountainPlannedClimbs = Self("mountain-planned-climbs")
}
