import CanIClimbKit
import CustomDump
import Dependencies
import Sharing
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("PlannedClimbDetailModel tests")
  struct PlannedClimbDetailModelTests {
    @Test("Unplanning")
    func unplanning() async throws {
      try await withDependencies {
        $0[Mountain.CatalogKey.self] = Mountain.MockCatalog(mountainResult: .success(.mock1))
        $0[Mountain.ClimbsKey.self] = Mountain.MockClimbs()
      } operation: {
        let model = PlannedClimbDetailModel(plannedClimb: SharedReader(value: .mock1))
        try await model.$mountain.load()

        expectNoDifference(model.destination, nil)
        model.cancelInvoked()
        expectNoDifference(
          model.destination,
          .alert(
            .confirmUnplanClimb(
              targetDate: Mountain.PlannedClimb.mock1.targetDate,
              mountainName: Mountain.mock1.name
            )
          )
        )

        var count = 0
        model.onUnplanned = { count += 1 }

        try await model.alert(action: .confirmUnplanClimb)

        expectNoDifference(count, 1)
        expectNoDifference(
          model.$unplanClimb.history.first?.arguments.mountainId,
          Mountain.mock1.id
        )
        expectNoDifference(
          model.$unplanClimb.history.first?.arguments.ids,
          [Mountain.PlannedClimb.mock1.id]
        )
      }
    }
  }
}
