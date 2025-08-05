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
  }
}

extension Mountain.ClimbPlanCreate.Alarm {
  public init(mountainName: String, date: Date) {
    self.name = "Starting climb for \(mountainName)!"
    self.date = date
  }
}

extension Mountain.ClimbPlanCreate.Alarm {
  public func newScheduleableAlarm() -> ScheduleableAlarm {
    ScheduleableAlarm(id: ScheduleableAlarm.ID(), title: self.name, date: self.date)
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
  }

  public enum PlanClimberKey: DependencyKey {
    public static var liveValue: any PlanClimber {
      fatalError()
    }
  }
}

extension Mountain {
  @MainActor
  public final class MockClimbPlanner: PlanClimber {
    private var results = [(ClimbPlanCreate, Result<PlannedClimb, any Error>)]()

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
        throw NoPlanError()
      }
      return try result.get()
    }

    private struct NoPlanError: Error {}
  }
}

extension Mountain {
  @MainActor
  public final class SucceedingClimbPlanner: PlanClimber {
    public init() {}

    public func plan(create: ClimbPlanCreate) async throws -> PlannedClimb {
      .mock1
    }
  }
}

// MARK: - ClimbUnplanner

extension Mountain {
  public protocol ClimbUnplanner: Sendable {
    func unplanClimbs(ids: OrderedSet<PlannedClimb.ID>) async throws
  }

  public enum ClimbUnplannerKey: DependencyKey {
    public static var liveValue: any ClimbUnplanner {
      fatalError()
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
        climbsStore.currentValue = climbsStore.currentValue ?? []
        climbsStore.currentValue?.append(plannedClimb)
      }

      return (arguments.mountain, plannedClimb)
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
}
