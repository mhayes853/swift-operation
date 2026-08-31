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
        $0[Mountain.CatalogKey.self] = Mountain.MockCatalog(mountainResult: .success(.mock1))

        let climbs = Mountain.MockClimbs()
        climbs.setPlanResult(for: .mock1, result: .success(.mock1))
        $0[Mountain.ClimbsKey.self] = climbs
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

    @Test("Achieves Climb, Updates Detail Model")
    func achievesClimbUpdatesDetailModel() async throws {
      try await withDependencies {
        $0[Mountain.CatalogKey.self] = Mountain.MockCatalog(mountainResult: .success(.mock1))

        let climbs = Mountain.MockClimbs()
        climbs.plannedClimbsResults[Mountain.mock1.id] = .success([.mock1])
        $0[Mountain.ClimbsKey.self] = climbs
        $0.date = .constant(.distantFuture)
      } operation: {
        let model = PlannedClimbsListModel(mountainId: Mountain.mock1.id)
        try await model.$plannedClimbs.load()

        model.plannedClimbDetailInvoked(id: Mountain.PlannedClimb.mock1.id)

        let detailModel = try #require(model.destination?[case: \.plannedClimbDetail])
        try await detailModel.$mountain.load()
        try await detailModel.$achieveClimb.mutate(
          with: Mountain.AchieveClimbArguments(
            id: Mountain.PlannedClimb.mock1.id,
            mountainId: Mountain.mock1.id
          )
        )
        expectNoDifference(detailModel.plannedClimb.achievedDate, .distantFuture)
        expectNoDifference(
          model.plannedClimbs?[id: Mountain.PlannedClimb.mock1.id]?.achievedDate,
          .distantFuture
        )
      }
    }

    @Test("Cancels Climb, Dismisses Detail Model")
    func cancelsClimbDismissesDetailModel() async throws {
      try await withDependencies {
        $0[Mountain.CatalogKey.self] = Mountain.MockCatalog(mountainResult: .success(.mock1))

        let climbs = Mountain.MockClimbs()
        climbs.plannedClimbsResults[Mountain.mock1.id] = .success([.mock1])
        $0[Mountain.ClimbsKey.self] = climbs
      } operation: {
        let model = PlannedClimbsListModel(mountainId: Mountain.mock1.id)
        try await model.$plannedClimbs.load()

        model.plannedClimbDetailInvoked(id: Mountain.PlannedClimb.mock1.id)

        let detailModel = try #require(model.destination?[case: \.plannedClimbDetail])
        try await detailModel.$mountain.load()
        detailModel.cancelInvoked()
        try await detailModel.alert(action: .confirmUnplanClimb)
        expectNoDifference(model.destination, nil)
      }
    }
  }
}
