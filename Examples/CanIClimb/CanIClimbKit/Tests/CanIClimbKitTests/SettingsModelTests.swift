import CanIClimbKit
import CustomDump
import Dependencies
import DependenciesTestSupport
import SQLiteData
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("SettingsModel tests")
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

    @Test("Full Successful Sign Out Flow, Pops Back")
    func fullSuccessfulSignOutFlow() async throws {
      try await withDependencies {
        $0[User.AuthenticatorKey.self] = User.MockAuthenticator()
      } operation: {
        let model = SettingsModel()
        model.path.append(.userSettings(UserSettingsModel(user: .mock1)))

        let userModel = try #require(model.path[0][case: \.userSettings])
        try await userModel.signOutInvoked()
        expectNoDifference(model.path, [])
      }
    }
  }
}
