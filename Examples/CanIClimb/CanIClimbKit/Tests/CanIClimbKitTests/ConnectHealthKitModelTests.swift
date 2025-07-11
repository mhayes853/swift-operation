import CanIClimbKit
import CustomDump
import DependenciesTestSupport
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("ConnectHealthKitModel tests")
  struct ConnectHealthKitModelTests {
    @Test(
      "Connects To HealthKit",
      .dependencies {
        $0[HealthPermissions.self] = HealthPermissions(
          database: $0.defaultDatabase,
          requester: HealthPermissions.MockRequester()
        )
      }
    )
    func connectsToHealthKit() async {
      let model = ConnectToHealthKitModel()
      await model.connectInvoked()
      expectNoDifference(model.isConnected, true)
    }

    @Test(
      "Is Not Connected When Failing to Connect to HealthKit",
      .dependencies {
        var requester = HealthPermissions.MockRequester()
        requester.shouldFail = true
        $0[HealthPermissions.self] = HealthPermissions(
          database: $0.defaultDatabase,
          requester: requester
        )
      }
    )
    func presentsErrorAlertWhenFailingToConnectToHealthKit() async {
      let model = ConnectToHealthKitModel()
      await model.connectInvoked()
      expectNoDifference(model.isConnected, false)
    }
  }
}
