import Dependencies
import Foundation
import OrderedCollections
import SharingQuery
import SwiftNavigation
import Tagged
import UUIDV7

// MARK: - ClimbPlanCreate

extension Mountain {
  public struct ClimbPlanCreate: Equatable, Sendable {
    public let mountainId: Mountain.ID
    public var targetDate: Date
    public var alarm: Alarm?

    public init(
      mountainId: Mountain.ID,
      targetDate: Date,
      alarm: Mountain.ClimbPlanCreate.Alarm? = nil
    ) {
      self.mountainId = mountainId
      self.targetDate = targetDate
      self.alarm = alarm
    }
  }
}

extension Mountain.ClimbPlanCreate {
  public struct Alarm: Equatable, Sendable {
    public var name: LocalizedStringResource
    public var date: Date

    public init(name: LocalizedStringResource, date: Date) {
      self.name = name
      self.date = date
    }

    public init(mountainName: String, date: Date) {
      self.name = "Starting climb for \(mountainName)!"
      self.date = date
    }

    public func newScheduleableAlarm() -> ScheduleableAlarm {
      ScheduleableAlarm(id: ScheduleableAlarm.ID(), title: self.name, date: self.date)
    }
  }
}

extension Mountain.ClimbPlanCreate {
  public static let mock1 = Self(
    mountainId: Mountain.PlannedClimb.mock1.mountainId,
    targetDate: Mountain.PlannedClimb.mock1.targetDate
  )
}

// MARK: - ClimbPlanner

extension Mountain {
  public protocol PlanClimber: Sendable {
    func plan(create: ClimbPlanCreate) async throws -> PlannedClimb
    func unplanClimbs(ids: OrderedSet<PlannedClimb.ID>) async throws
  }

  public enum PlanClimberKey: DependencyKey {
    public static var liveValue: any PlanClimber {
      PlannedMountainClimbs.shared
    }
  }
}

extension Mountain {
  @MainActor
  public final class MockClimbPlanner: PlanClimber {
    private var results = [(ClimbPlanCreate, Result<PlannedClimb, any Error>)]()
    public var shouldFailUnplan = false
    public private(set) var unplannedIdSets = [OrderedSet<Mountain.PlannedClimb.ID>]()

    public nonisolated init() {}

    public func setResult(for create: ClimbPlanCreate, result: Result<PlannedClimb, any Error>) {
      if let index = self.results.firstIndex(where: { $0.0 == create }) {
        self.results[index] = (create, result)
      } else {
        self.results.append((create, result))
      }
    }

    public func plan(create: ClimbPlanCreate) async throws -> PlannedClimb {
      guard let (_, result) = self.results.first(where: { $0.0 == create }) else {
        throw SomeError()
      }
      return try result.get()
    }

    public func unplanClimbs(ids: OrderedSet<Mountain.PlannedClimb.ID>) async throws {
      if self.shouldFailUnplan {
        throw SomeError()
      }
      self.unplannedIdSets.append(ids)
    }

    private struct SomeError: Error {}
  }
}

extension Mountain {
  @MainActor
  public final class SucceedingClimbPlanner: PlanClimber {
    public init() {}

    public func plan(create: ClimbPlanCreate) async throws -> PlannedClimb {
      PlannedClimb(
        id: Mountain.PlannedClimb.ID(),
        mountainId: create.mountainId,
        targetDate: create.targetDate,
        achievedDate: nil,
        alarm: create.alarm?.newScheduleableAlarm()
      )
    }

    public func unplanClimbs(ids: OrderedSet<Mountain.PlannedClimb.ID>) async throws {
    }
  }
}

// MARK: - Mutations

extension Mountain {
  public static let planClimbMutation = PlanClimbMutation()
    .alerts { value in
      let (mountain, plannedClimb) = value.returnValue
      return .planClimbSuccess(mountainName: mountain.name, targetDate: plannedClimb.targetDate)
    } failure: { _ in
      .planClimbFailure
    }

  public struct PlanClimbMutation: MutationRequest, Hashable {
    public struct Arguments: Sendable {
      public let mountain: Mountain
      public let create: ClimbPlanCreate

      public init(mountain: Mountain, create: ClimbPlanCreate) {
        self.mountain = mountain
        self.create = create
      }
    }

    public func mutate(
      with arguments: Arguments,
      in context: QueryContext,
      with continuation: QueryContinuation<(Mountain, PlannedClimb)>
    ) async throws -> (Mountain, PlannedClimb) {
      @Dependency(Mountain.PlanClimberKey.self) var planner
      @Dependency(\.defaultQueryClient) var client

      let plannedClimb = try await planner.plan(create: arguments.create)

      let climbsStore = client.store(for: Mountain.plannedClimbsQuery(for: arguments.mountain.id))
      climbsStore.withExclusiveAccess {
        var currentValue = $0.currentValue ?? []
        currentValue.append(plannedClimb)
        currentValue.sort { $0.targetDate > $1.targetDate }
        $0.currentValue = currentValue
      }

      return (arguments.mountain, plannedClimb)
    }
  }
}

extension Mountain {
  public static let unplanClimbsMutation = UnplanClimbsMutation()
    .alerts { _ in
      nil
    } failure: { error in
      (error as? UnplanClimbsError).map { .unplanClimbsFailure(count: $0.ids.count) }
    }

  public struct UnplanClimbsMutation: MutationRequest, Hashable {
    public struct Arguments: Sendable {
      public let mountainId: Mountain.ID
      public let ids: OrderedSet<PlannedClimb.ID>

      public init(mountainId: Mountain.ID, ids: OrderedSet<PlannedClimb.ID>) {
        self.ids = ids
        self.mountainId = mountainId
      }
    }

    public func mutate(
      with arguments: Arguments,
      in context: QueryContext,
      with continuation: QueryContinuation<Void>
    ) async throws {
      @Dependency(Mountain.PlanClimberKey.self) var planner
      @Dependency(\.defaultQueryClient) var client

      let climbsStore = client.store(for: Mountain.plannedClimbsQuery(for: arguments.mountainId))
      var currentPlans: IdentifiedArrayOf<Mountain.PlannedClimb>?
      var lastUpdatedAt: Date?

      do {
        climbsStore.withExclusiveAccess {
          currentPlans = $0.currentValue
          $0.currentValue?.removeAll(where: { arguments.ids.contains($0.id) })
          lastUpdatedAt = $0.valueLastUpdatedAt
        }
        try await planner.unplanClimbs(ids: arguments.ids)
      } catch {
        climbsStore.withExclusiveAccess {
          guard $0.valueLastUpdatedAt == lastUpdatedAt else { return }
          $0.currentValue = currentPlans
        }
        throw UnplanClimbsError(ids: arguments.ids, inner: error)
      }
    }
  }

  public struct UnplanClimbsError: Error {
    public let ids: OrderedSet<PlannedClimb.ID>
    public let inner: any Error

    public init(ids: OrderedSet<PlannedClimb.ID>, inner: any Error) {
      self.ids = ids
      self.inner = inner
    }
  }
}

// MARK: - Alerts

extension AlertState where Action == Never {
  public static func planClimbSuccess(mountainName: String, targetDate: Date) -> Self {
    Self {
      TextState("Climb Planned!")
    } message: {
      TextState(
        """
        Your climb for \(mountainName) has been planned successfully for \
        \(targetDate.formatted(date: .complete, time: .omitted)) at \
        \(targetDate.formatted(date: .omitted, time: .shortened))
        """
      )
    }
  }

  public static let planClimbFailure = Self.remoteOperationError {
    TextState("Failed to Plan Climb")
  } message: {
    TextState("Your climb could not be planned. Please try again.")
  }

  public static func unplanClimbsFailure(count: Int) -> Self {
    Self.remoteOperationError {
      if count == 1 {
        TextState("Failed to Unplan Climb")
      } else {
        TextState("Failed to Unplan \(count) Climbs")
      }
    } message: {
      if count == 1 {
        TextState("Your climb could not be unplanned. Please try again.")
      } else {
        TextState("Your \(count) climbs could not be unplanned. Please try again.")
      }
    }
  }
}
