import Dependencies
import Operation
import Tagged
import UUIDV7

// MARK: - Query

extension Mountain {
  @QueryRequest(path: .custom { (id: Mountain.ID) in .mountainPlannedClimbs.appending(id) })
  public static func plannedClimbsQuery(
    for id: Mountain.ID,
    continuation: OperationContinuation<IdentifiedArrayOf<PlannedClimb>, any Error>
  ) async throws -> IdentifiedArrayOf<PlannedClimb> {
    @Dependency(Mountain.ClimbsKey.self) var climbs
    continuation.yield(try await climbs.localPlannedClimbs(for: id))
    return try await climbs.plannedClimbs(for: id)
  }
}

extension OperationPath {
  public static let mountainPlannedClimbs = Self("mountain-planned-climbs")
}
