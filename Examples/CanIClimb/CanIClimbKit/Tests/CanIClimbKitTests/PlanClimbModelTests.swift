import CanIClimbKit
import CustomDump
import Dependencies
import SharingQuery
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("PlanClimbModel tests")
  struct PlanClimbModelTests {
    @Test("Authorization For Alarms Is Authorized, Toggles Alarm Toggle")
    func authorizationForAlarmsIsAuthorizedTogglesAlarmToggle() async throws {
      let authorization = ScheduleableAlarm.MockAuthorization()
      authorization.status = .authorized

      try await withDependencies {
        $0[ScheduleableAlarm.AuthorizationStatus.ObserverKey.self] = authorization
        $0[ScheduleableAlarm.AuthorizerKey.self] = authorization
        $0[Mountain.LoaderKey.self] = Mountain.MockLoader(result: .success(.mock1))
      } operation: {
        let model = PlanClimbModel(mountainId: Mountain.ID())

        expectNoDifference(model.shouldAddAlarm, false)
        try await model.alarmToggled()
        expectNoDifference(model.shouldAddAlarm, true)
      }
    }

    @Test("Authorization For Alarms Is Authorized, Toggles Alarm Twice, Is Disabled")
    func authorizationForAlarmsIsAuthorizedTogglesAlarmTwiceIsDisabled() async throws {
      let authorization = ScheduleableAlarm.MockAuthorization()
      authorization.status = .authorized

      try await withDependencies {
        $0[ScheduleableAlarm.AuthorizationStatus.ObserverKey.self] = authorization
        $0[ScheduleableAlarm.AuthorizerKey.self] = authorization
        $0[Mountain.LoaderKey.self] = Mountain.MockLoader(result: .success(.mock1))
      } operation: {
        let model = PlanClimbModel(mountainId: Mountain.ID())

        try await model.alarmToggled()
        try await model.alarmToggled()
        expectNoDifference(model.shouldAddAlarm, false)
      }
    }

    @Test("Toggles Alarm, Asks For Alarms Permission Before Enabling")
    func togglesAlarmAsksForAlarmsPermissionBeforeEnabling() async throws {
      let authorization = ScheduleableAlarm.MockAuthorization()
      authorization.status = .notDetermined
      authorization.statusOnRequest = .authorized

      try await withDependencies {
        $0[ScheduleableAlarm.AuthorizationStatus.ObserverKey.self] = authorization
        $0[ScheduleableAlarm.AuthorizerKey.self] = authorization
        $0[Mountain.LoaderKey.self] = Mountain.MockLoader(result: .success(.mock1))
      } operation: {
        let model = PlanClimbModel(mountainId: Mountain.ID())

        try await model.alarmToggled()
        expectNoDifference(model.alarmsAuthorization, .authorized)
        expectNoDifference(model.shouldAddAlarm, true)
      }
    }

    @Test("Toggles Alarm, Does Not Enable When Permission Denied")
    func togglesAlarmDoesNotEnableWhenPermissionDenied() async throws {
      let authorization = ScheduleableAlarm.MockAuthorization()
      authorization.status = .notDetermined
      authorization.statusOnRequest = .unauthorized

      try await withDependencies {
        $0[ScheduleableAlarm.AuthorizationStatus.ObserverKey.self] = authorization
        $0[ScheduleableAlarm.AuthorizerKey.self] = authorization
        $0[Mountain.LoaderKey.self] = Mountain.MockLoader(result: .success(.mock1))
      } operation: {
        let model = PlanClimbModel(mountainId: Mountain.ID())

        try await model.alarmToggled()
        expectNoDifference(model.alarmsAuthorization, .unauthorized)
        expectNoDifference(model.shouldAddAlarm, false)
      }
    }
  }
}
