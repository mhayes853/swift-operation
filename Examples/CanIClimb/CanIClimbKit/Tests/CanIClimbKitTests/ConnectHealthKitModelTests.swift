import CanIClimbKit
import CustomDump
import DependenciesTestSupport
import Testing

@MainActor
@Suite("ConnectHealthKitModel tests", .dependency(\.defaultDatabase, try! canIClimbDatabase()))
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

    expectNoDifference(model.isConnected, false)

    await model.connectInvoked()

    expectNoDifference(model.destination, .alert(.successfullyConnectedToHealthKit))
    expectNoDifference(model.isConnected, true)
  }

  @Test(
    "Presents Error Alert When Failing to Connect to HealthKit",
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

    expectNoDifference(model.destination, .alert(.failedToConnectToHealthKit))
    expectNoDifference(model.isConnected, false)
  }
}
