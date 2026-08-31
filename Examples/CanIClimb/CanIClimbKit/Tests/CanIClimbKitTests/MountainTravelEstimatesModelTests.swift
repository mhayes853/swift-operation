import CanIClimbKit
import CustomDump
import Dependencies
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("MountainTravelEstimatesModel tests")
  struct MountainTravelEstimatedModelTests {
    @Test("Presents Alert When Directions Cannot Open")
    func presentsAlertWhenDirectionsCannotOpen() async {
      await withDependencies {
        let maps = MockMapsClient()
        maps.openDirectionsResult = false
        $0[MapsClientKey.self] = maps
      } operation: {
        let model = MountainTravelEstimatesModel(mountain: .mock1)
        await model.travelRouteInvoked(for: .walking)
        expectNoDifference(model.destination, .alert(.failedToOpenDirections))
      }
    }
  }
}
