import CanIClimbKit
import CustomDump
import Dependencies
import SharingQuery
import Synchronization
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("Mountain+PlanClimbing tests")
  struct MountainPlanClimbingTests {
    @Test("Updates Planned Climbed List When Planning New Climb")
    func updatesPlannedClimbedListWhenPlanningNewClimb() async throws {
      try await withDependencies {
        let planner = Mountain.MockClimbPlanner()
        planner.setResult(for: .mock1, result: .success(.mock1))
        $0[Mountain.PlanClimberKey.self] = planner
        $0[Mountain.PlannedClimbsLoaderKey.self] = Mountain.MockPlannedClimbsLoader()
      } operation: {
        @Dependency(\.defaultQueryClient) var client
        let climbsStore = client.store(for: Mountain.plannedClimbsQuery(for: Mountain.mock1.id))
        let planStore = client.store(for: Mountain.planClimbMutation)

        try await planStore.mutate(
          with: Mountain.PlanClimbMutation.Arguments(mountain: .mock1, create: .mock1)
        )
        expectNoDifference(climbsStore.currentValue, [.mock1])
      }
    }

    @Test("Unplan Optimistically Updates Planned List")
    func unplanOptimisticallyUpdatesPlannedList() async throws {
      try await withDependencies {
        let loader = Mountain.MockPlannedClimbsLoader()
        loader.results[Mountain.mock1.id] = .success([.mock1])

        $0[Mountain.PlanClimberKey.self] = Mountain.MockClimbPlanner()
        $0[Mountain.PlannedClimbsLoaderKey.self] = loader
      } operation: {
        @Dependency(\.defaultQueryClient) var client
        let climbsStore = client.store(for: Mountain.plannedClimbsQuery(for: Mountain.mock1.id))
        try await climbsStore.fetch()

        let unplanStore = client.store(for: Mountain.unplanClimbsMutation)
        try await unplanStore.mutate(
          with: Mountain.UnplanClimbsMutation.Arguments(
            mountainId: Mountain.mock1.id,
            ids: [Mountain.PlannedClimb.mock1.id]
          )
        )

        expectNoDifference(climbsStore.currentValue, [])
      }
    }

    @Test("Unplan Failure Rollsback Planned List Update")
    func unplanFailureRollsbackPlannedListUpdate() async throws {
      try await withDependencies {
        let loader = Mountain.MockPlannedClimbsLoader()
        loader.results[Mountain.mock1.id] = .success([.mock1])

        let planner = Mountain.MockClimbPlanner()
        planner.shouldFailUnplan = true

        $0[Mountain.PlanClimberKey.self] = planner
        $0[Mountain.PlannedClimbsLoaderKey.self] = loader
      } operation: {
        @Dependency(\.defaultQueryClient) var client
        let climbsStore = client.store(for: Mountain.plannedClimbsQuery(for: Mountain.mock1.id))
        try await climbsStore.fetch()

        let unplanStore = client.store(for: Mountain.unplanClimbsMutation)
        _ = try? await unplanStore.mutate(
          with: Mountain.UnplanClimbsMutation.Arguments(
            mountainId: Mountain.mock1.id,
            ids: [Mountain.PlannedClimb.mock1.id]
          )
        )

        expectNoDifference(climbsStore.currentValue, [.mock1])
      }
    }
  }
}
