import Dependencies
import SharingOperation
import Tagged
import UUIDV7

// MARK: - ClimbAchiever

extension Mountain {
  public protocol ClimbAchiever: Sendable {
    func achieveClimb(id: PlannedClimb.ID) async throws
    func unachieveClimb(id: PlannedClimb.ID) async throws
  }

  public enum ClimbAchieverKey: DependencyKey {
    public static var liveValue: any ClimbAchiever {
      PlannedMountainClimbs.shared
    }
  }
}

extension Mountain {
  public struct NoopClimbAchiever: ClimbAchiever {
    public init() {}

    public func achieveClimb(id: PlannedClimb.ID) async throws {}
    public func unachieveClimb(id: PlannedClimb.ID) async throws {}
  }
}

// MARK: - Mutations

extension Mountain {
  public static let achieveClimbMutation = AchieveClimbMutation()

  public struct AchieveClimbMutation: MutationRequest, Hashable, Sendable {
    public struct Arguments: Sendable {
      public let id: PlannedClimb.ID
      public let mountainId: Mountain.ID

      public init(id: Mountain.PlannedClimb.ID, mountainId: Mountain.ID) {
        self.id = id
        self.mountainId = mountainId
      }
    }

    public func mutate(
      isolation: isolated (any Actor)?,
      with arguments: Arguments,
      in context: OperationContext,
      with continuation: OperationContinuation<Void, any Error>
    ) async throws {
      @Dependency(Mountain.ClimbAchieverKey.self) var achiever
      @Dependency(\.defaultOperationClient) var client
      @Dependency(\.date) var now

      if context.isFirstRunAttempt {
        let climbsStore = client.store(for: Mountain.plannedClimbsQuery(for: arguments.mountainId))
        climbsStore.currentValue?[id: arguments.id]?.achievedDate = now()
      }

      try await achiever.achieveClimb(id: arguments.id)
    }
  }
}

extension Mountain {
  public static let unachieveClimbMutation = UnachieveClimbMutation()

  public struct UnachieveClimbMutation: MutationRequest, Hashable, Sendable {
    public struct Arguments: Sendable {
      public let id: PlannedClimb.ID
      public let mountainId: Mountain.ID

      public init(id: Mountain.PlannedClimb.ID, mountainId: Mountain.ID) {
        self.id = id
        self.mountainId = mountainId
      }
    }

    public func mutate(
      isolation: isolated (any Actor)?,
      with arguments: Arguments,
      in context: OperationContext,
      with continuation: OperationContinuation<Void, any Error>
    ) async throws {
      @Dependency(Mountain.ClimbAchieverKey.self) var achiever
      @Dependency(\.defaultOperationClient) var client

      let climbsStore = client.store(for: Mountain.plannedClimbsQuery(for: arguments.mountainId))
      if context.isFirstRunAttempt {
        climbsStore.currentValue?[id: arguments.id]?.achievedDate = nil
      }

      try await achiever.unachieveClimb(id: arguments.id)
    }
  }
}
