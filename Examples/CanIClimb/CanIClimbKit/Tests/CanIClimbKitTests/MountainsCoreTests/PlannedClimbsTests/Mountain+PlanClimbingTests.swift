import CanIClimbKit
import CustomDump
import Dependencies
import SharingQuery
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("Mountain+PlanClimbing tests")
  struct MountainPlanClimbingTests {
    @Test("Updates Planned Climbed List When Planning New Climb")
    func updatesPlannedClimbedListWhenPlanningNewClimb() async throws {
      try await withDependencies {
        let planner = Mountain.MockClimbPlanner()
        planner.results[.mock1] = .success(.mock1)
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
  }
}
