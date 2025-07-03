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
}
