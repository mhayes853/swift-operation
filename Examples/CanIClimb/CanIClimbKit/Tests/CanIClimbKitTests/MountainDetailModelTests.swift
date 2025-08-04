import CanIClimbKit
import CustomDump
import Dependencies
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("MountainDetailModel tests")
  struct MountainDetailModelTests {
    @Test("Plans Climb, Dismisses Climb Sheet When Finished")
    func plansClimbDismissesClimbSheetWhenFinished() async throws {
      try await withDependencies {
        $0[ScheduleableAlarm.AuthorizerKey.self] = ScheduleableAlarm.MockAuthorizer()
        $0[Mountain.LoaderKey.self] = Mountain.MockLoader(result: .success(.mock1))

        let planner = Mountain.MockClimbPlanner()
        planner.setResult(for: .mock1, result: .success(.mock1))
        $0[Mountain.PlanClimberKey.self] = planner
      } operation: {
        let model = MountainDetailModel(id: Mountain.mock1.id)
        try await model.$mountain.load()

        model.planClimbInvoked()

        let planModel = try #require(model.destination?[case: \.planClimb])
        planModel.targetDate = Mountain.ClimbPlanCreate.mock1.targetDate

        try await planModel.submitted()
        expectNoDifference(model.destination, nil)
      }
    }
  }
}
