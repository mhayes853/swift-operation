import CanIClimbKit
import CustomDump
import Dependencies
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("PlannedClimbsListModel tests")
  struct PlannedClimbsListModelTests {
    @Test("Plans Climb, Dismisses Climb Sheet When Finished")
    func plansClimbDismissesClimbSheetWhenFinished() async throws {
      try await withDependencies {
        $0[ScheduleableAlarm.AuthorizerKey.self] = ScheduleableAlarm.MockAuthorizer()
        $0[Mountain.LoaderKey.self] = Mountain.MockLoader(result: .success(.mock1))

        let planner = Mountain.MockClimbPlanner()
        planner.setResult(for: .mock1, result: .success(.mock1))
        $0[Mountain.PlanClimberKey.self] = planner
        $0[Mountain.PlannedClimbsLoaderKey.self] = Mountain.MockPlannedClimbsLoader()
      } operation: {
        let model = PlannedClimbsListModel(mountainId: Mountain.mock1.id)
        model.planClimbInvoked()

        let planModel = try #require(model.destination?[case: \.planClimb])
        try await planModel.$mountain.load()
        planModel.targetDate = Mountain.ClimbPlanCreate.mock1.targetDate

        try await planModel.submitted()
        expectNoDifference(model.destination, nil)
      }
    }
  }
}
