import Dependencies
import IdentifiedCollections
import OrderedCollections
import Tagged
import UUIDV7

extension Mountain {
  public protocol Climbs: Sendable {
    func plan(create: ClimbPlanCreate) async throws -> PlannedClimb
    func unplanClimbs(ids: OrderedSet<PlannedClimb.ID>) async throws
    func achieveClimb(id: PlannedClimb.ID) async throws
    func unachieveClimb(id: PlannedClimb.ID) async throws
    func localPlannedClimbs(for id: Mountain.ID) async throws -> IdentifiedArrayOf<PlannedClimb>
    func plannedClimbs(for id: Mountain.ID) async throws -> IdentifiedArrayOf<PlannedClimb>
  }

  public enum ClimbsKey: DependencyKey {
    public static var liveValue: any Climbs {
      PlannedMountainClimbs.shared
    }
  }
}

extension Mountain {
  @MainActor
  public final class MockClimbs: Climbs {
    private var planResults = [(ClimbPlanCreate, Result<PlannedClimb, any Error>)]()
    public var plannedClimbsResults = [
      Mountain.ID: Result<IdentifiedArrayOf<PlannedClimb>, any Error>
    ]()
    public var localPlannedClimbsResults = [
      Mountain.ID: Result<IdentifiedArrayOf<PlannedClimb>, any Error>
    ]()
    public var succeedsUnconfiguredPlans = false
    public var shouldFailUnplan = false
    public private(set) var unplannedIdSets = [OrderedSet<Mountain.PlannedClimb.ID>]()

    public init() {}

    public func setPlanResult(
      for create: ClimbPlanCreate,
      result: Result<PlannedClimb, any Error>
    ) {
      if let index = self.planResults.firstIndex(where: { $0.0 == create }) {
        self.planResults[index] = (create, result)
      } else {
        self.planResults.append((create, result))
      }
    }

    public func plan(create: ClimbPlanCreate) async throws -> PlannedClimb {
      if let (_, result) = self.planResults.first(where: { $0.0 == create }) {
        return try result.get()
      }
      guard self.succeedsUnconfiguredPlans else { throw MissingResultError() }
      return PlannedClimb(
        id: Mountain.PlannedClimb.ID(),
        mountainId: create.mountainId,
        targetDate: create.targetDate,
        achievedDate: nil,
        alarm: create.alarm?.newScheduleableAlarm()
      )
    }

    public func unplanClimbs(ids: OrderedSet<Mountain.PlannedClimb.ID>) async throws {
      if self.shouldFailUnplan {
        throw UnplanError()
      }
      self.unplannedIdSets.append(ids)
    }

    public func achieveClimb(id: PlannedClimb.ID) async throws {}

    public func unachieveClimb(id: PlannedClimb.ID) async throws {}

    public func localPlannedClimbs(
      for id: Mountain.ID
    ) async throws -> IdentifiedArrayOf<PlannedClimb> {
      try self.localPlannedClimbsResults[id]?.get() ?? []
    }

    public func plannedClimbs(for id: Mountain.ID) async throws -> IdentifiedArrayOf<PlannedClimb> {
      guard let result = self.plannedClimbsResults[id] else { throw MissingResultError() }
      return try result.get()
    }

    private struct MissingResultError: Error {}
    private struct UnplanError: Error {}
  }
}
