import Dependencies
import SharingOperation
import Tagged
import UUIDV7

// MARK: - Mutations

extension Mountain {
  public struct AchieveClimbArguments: Sendable {
    public let id: PlannedClimb.ID
    public let mountainId: Mountain.ID

    public init(id: Mountain.PlannedClimb.ID, mountainId: Mountain.ID) {
      self.id = id
      self.mountainId = mountainId
    }
  }

  @MutationRequest
  public static func achieveClimbMutation(
    arguments: AchieveClimbArguments,
    context: OperationContext
  ) async throws {
    @Dependency(Mountain.ClimbsKey.self) var climbs
    @Dependency(\.defaultOperationClient) var client
    @Dependency(\.date) var now

    if context.isFirstRunAttempt {
      let climbsStore = client.store(for: Mountain.$plannedClimbsQuery(for: arguments.mountainId))
      climbsStore.currentValue?[id: arguments.id]?.achievedDate = now()
    }

    try await climbs.achieveClimb(id: arguments.id)
  }
}

extension Mountain {
  public struct UnachieveClimbArguments: Sendable {
    public let id: PlannedClimb.ID
    public let mountainId: Mountain.ID

    public init(id: Mountain.PlannedClimb.ID, mountainId: Mountain.ID) {
      self.id = id
      self.mountainId = mountainId
    }
  }

  @MutationRequest
  public static func unachieveClimbMutation(
    arguments: UnachieveClimbArguments,
    context: OperationContext
  ) async throws {
    @Dependency(Mountain.ClimbsKey.self) var climbs
    @Dependency(\.defaultOperationClient) var client

    let climbsStore = client.store(for: Mountain.$plannedClimbsQuery(for: arguments.mountainId))
    if context.isFirstRunAttempt {
      climbsStore.currentValue?[id: arguments.id]?.achievedDate = nil
    }

    try await climbs.unachieveClimb(id: arguments.id)
  }
}
