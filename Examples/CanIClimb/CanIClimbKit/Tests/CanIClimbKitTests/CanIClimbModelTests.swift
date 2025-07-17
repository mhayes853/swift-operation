import CanIClimbKit
import CustomDump
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("CanIClimbModel tests")
  struct CanIClimbModelTests {
    @Test("Presents Onboarding Flow When Not Completed")
    func presentOnboardingFlowWhenNotCompleted() async throws {
      let model = CanIClimbModel()
      try await model.appeared()

      let onboardingModel = try #require(model.destination?[case: \.onboarding])
      try await onboardingModel.runOnboardingFlow(
        fillingIn: .mock,
        locationPermissions: .skip,
        signInCredentials: nil,
        connectHealthKit: .skip
      )

      expectNoDifference(model.destination, nil)
    }

    @Test("Doesn't Present Onboarding Flow When Completed")
    func doesNotPresentOnboardingFlowWhenCompleted() async throws {
      let model = CanIClimbModel()
      try await model.appeared()
      try await model.destination?[case: \.onboarding]?
        .runOnboardingFlow(
          fillingIn: .mock,
          locationPermissions: .skip,
          signInCredentials: nil,
          connectHealthKit: .skip
        )

      let model2 = CanIClimbModel()
      try await model2.appeared()
      expectNoDifference(model2.destination, nil)
    }
  }
}
