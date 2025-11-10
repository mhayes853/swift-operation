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
  @QueryRequest(path: .custom { (id: Mountain.ID) in .mountainPlannedClimbs.appending(id) })
  public static func plannedClimbsQuery(
    for id: Mountain.ID,
    continuation: OperationContinuation<IdentifiedArrayOf<PlannedClimb>, any Error>
  ) async throws -> IdentifiedArrayOf<PlannedClimb> {
    @Dependency(Mountain.PlannedClimbsLoaderKey.self) var loader
    continuation.yield(try await loader.localPlannedClimbs(for: id))
    return try await loader.plannedClimbs(for: id)
  }
}

extension OperationPath {
  public static let mountainPlannedClimbs = Self("mountain-planned-climbs")
}
