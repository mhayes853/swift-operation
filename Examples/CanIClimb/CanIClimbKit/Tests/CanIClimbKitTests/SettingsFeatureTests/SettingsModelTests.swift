import CanIClimbKit
import CustomDump
import Dependencies
import DependenciesTestSupport
import SharingGRDB
import Testing

@MainActor
@Suite("SettingsModel tests", .dependency(\.defaultDatabase, try! canIClimbDatabase()))
struct SettingsModelTests {
  @Test("Persists Settings When Updated")
  func persistsSettingsWhenUpdated() {
    let model = SettingsModel()
    model.settings.metricPreference = .metric

    let model2 = SettingsModel()
    expectNoDifference(model2.settings.metricPreference, .metric)
  }

  @Test("Persists User Profile When Updated")
  func persistsUserProfileWhenUpdated() {
    let model = SettingsModel()
    model.userProfile.gender = .female

    let model2 = SettingsModel()
    expectNoDifference(model2.userProfile.gender, .female)
  }

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
    let model = SettingsModel()

    expectNoDifference(model.isConnectedToHealthKit, false)

    await model.connectToHealthKitInvoked()

    expectNoDifference(model.destination, .alert(.successfullyConnectedToHealthKit))
    expectNoDifference(model.isConnectedToHealthKit, true)
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
    let model = SettingsModel()

    await model.connectToHealthKitInvoked()

    expectNoDifference(model.destination, .alert(.failedToConnectToHealthKit))
    expectNoDifference(model.isConnectedToHealthKit, false)
  }
}
