import Dependencies
import GRDB
import IdentifiedCollections
import StructuredQueriesGRDB

// MARK: - PlannedMountainClimbs

public final class PlannedMountainClimbs: Sendable {
  private let database: any DatabaseWriter
  private let api: CanIClimbAPI

  public init(database: any DatabaseWriter, api: CanIClimbAPI = .shared) {
    self.database = database
    self.api = api
  }
}

// MARK: - PlanClimber

extension PlannedMountainClimbs: Mountain.PlanClimber {
  public func plan(create: Mountain.ClimbPlanCreate) async throws -> Mountain.PlannedClimb {
    fatalError()
  }
}

// MARK: - PlannedClimbsLoader

extension PlannedMountainClimbs: Mountain.PlannedClimbsLoader {
  public func plannedClimbs(
    for id: Mountain.ID
  ) async throws -> IdentifiedArrayOf<Mountain.PlannedClimb> {
    []
  }

  public func localPlannedClimbs(
    for id: Mountain.ID
  ) async throws -> IdentifiedArrayOf<Mountain.PlannedClimb> {
    []
  }
}
