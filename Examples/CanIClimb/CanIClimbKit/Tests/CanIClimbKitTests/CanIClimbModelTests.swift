import CanIClimbKit
import CustomDump
import Dependencies
import DependenciesTestSupport
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite(
    "CanIClimbModel tests",
    .dependencies {
      $0.continuousClock = ImmediateClock()
      $0[Mountain.SearcherKey.self] = Mountain.MockSearcher()
    }
  )
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

    @Test("Doesn't Present Onboarding Flow When Completed On Next Launch")
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

      try await withDependencies {
        $0[ApplicationLaunch.ID.self] = ApplicationLaunch.ID()
      } operation: {
        let model2 = CanIClimbModel()
        try await model2.appeared()
        expectNoDifference(model2.destination, nil)
      }
    }

    @Test("Presents OperationDevTools When Device Shaken After Appearance")
    func presentsOperationDevToolsWhenDeviceShaken() async throws {
      @Dependency(\.notificationCenter) var center

      let model = CanIClimbModel()
      try await model.appeared()

      expectNoDifference(model.devTools, nil)
      center.post(DeviceShakeMessage())
      expectNoDifference(model.devTools != nil, true)

      await model.disappeared()
    }

    @Test("Dismisses OperationDevTools When Dismissed")
    func dismissesOperationDevToolsWhenDismissed() async throws {
      @Dependency(\.notificationCenter) var center

      let model = CanIClimbModel()
      try await model.appeared()

      center.post(DeviceShakeMessage())
      model.devTools?.dismissed()
      expectNoDifference(model.devTools, nil)

      await model.disappeared()
    }

    @Test("Does Not Re-Present OperationDevTools When Device Shaken After Appearance")
    func doesNotRePresentOperationDevToolsWhenDeviceShaken() async throws {
      @Dependency(\.notificationCenter) var center

      let model = CanIClimbModel()
      try await model.appeared()

      expectNoDifference(model.devTools, nil)
      center.post(DeviceShakeMessage())
      let analyzer = try #require(model.devTools)

      center.post(DeviceShakeMessage())
      expectNoDifference(model.devTools, analyzer)

      await model.disappeared()
    }

    @Test("Stops Presenting OperationDevTools When Device Shaken After Disappearance")
    func stopsPresentingOperationDevToolsWhenDeviceShakenAfterDisappearance() async throws {
      @Dependency(\.notificationCenter) var center

      let model = CanIClimbModel()
      try await model.appeared()
      await model.disappeared()

      expectNoDifference(model.devTools, nil)
      center.post(DeviceShakeMessage())
      expectNoDifference(model.devTools, nil)
    }

    @Test("Records Launch When Appeared")
    func recordsLaunchWhenAppeared() async throws {
      @Dependency(ApplicationLaunch.ID.self) var launchID
      @Dependency(\.defaultDatabase) var database

      let model = CanIClimbModel()
      try await model.appeared()

      let launches = try await database.read { try ApplicationLaunchRecord.all.fetchAll($0) }
      expectNoDifference(
        launches,
        [
          ApplicationLaunchRecord(
            id: launchID,
            localizedDeviceName: DeviceInfo.testValue.localizedModelName
          )
        ]
      )
    }
  }
}
