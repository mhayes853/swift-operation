import CanIClimbKit
import CustomDump
import Dependencies
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

    @Test("Presents QueryAnalyzer When Device Shaken After Appearance")
    func presentsQueryAnalyzerWhenDeviceShaken() async throws {
      @Dependency(\.notificationCenter) var center

      let model = CanIClimbModel()
      try await model.appeared()

      expectNoDifference(model.analyzer, nil)
      center.post(DeviceShakeMessage())
      expectNoDifference(model.analyzer != nil, true)

      model.disappeared()
    }

    @Test("Does Not Re-Present QueryAnalyzer When Device Shaken After Appearance")
    func doesNotRePresentQueryAnalyzerWhenDeviceShaken() async throws {
      @Dependency(\.notificationCenter) var center

      let model = CanIClimbModel()
      try await model.appeared()

      expectNoDifference(model.analyzer, nil)
      center.post(DeviceShakeMessage())
      let analyzer = try #require(model.analyzer)

      center.post(DeviceShakeMessage())
      expectNoDifference(model.analyzer, analyzer)

      model.disappeared()
    }

    @Test("Stops Presenting QueryAnalyzer When Device Shaken After Disappearance")
    func stopsPresentingQueryAnalyzerWhenDeviceShakenAfterDisappearance() async throws {
      @Dependency(\.notificationCenter) var center

      let model = CanIClimbModel()
      try await model.appeared()
      model.disappeared()

      expectNoDifference(model.analyzer, nil)
      center.post(DeviceShakeMessage())
      expectNoDifference(model.analyzer, nil)
    }
  }
}
