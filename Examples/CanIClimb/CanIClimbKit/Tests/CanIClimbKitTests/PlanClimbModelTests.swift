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
      let authorizer = ScheduleableAlarm.MockAuthorizer()
      authorizer.status = .authorized

      try await withDependencies {
        $0[ScheduleableAlarm.AuthorizerKey.self] = authorizer
        $0[Mountain.LoaderKey.self] = Mountain.MockLoader(result: .success(.mock1))
      } operation: {
        let model = PlanClimbModel(mountainId: Mountain.mock1.id)

        expectNoDifference(model.shouldAddAlarm, false)
        try await model.alarmToggled()
        expectNoDifference(model.shouldAddAlarm, true)
      }
    }

    @Test("Authorization For Alarms Is Authorized, Toggles Alarm Twice, Is Disabled")
    func authorizationForAlarmsIsAuthorizedTogglesAlarmTwiceIsDisabled() async throws {
      let authorizer = ScheduleableAlarm.MockAuthorizer()
      authorizer.status = .authorized

      try await withDependencies {
        $0[ScheduleableAlarm.AuthorizerKey.self] = authorizer
        $0[Mountain.LoaderKey.self] = Mountain.MockLoader(result: .success(.mock1))
      } operation: {
        let model = PlanClimbModel(mountainId: Mountain.mock1.id)

        try await model.alarmToggled()
        try await model.alarmToggled()
        expectNoDifference(model.shouldAddAlarm, false)
      }
    }

    @Test("Toggles Alarm, Asks For Alarms Permission Before Enabling")
    func togglesAlarmAsksForAlarmsPermissionBeforeEnabling() async throws {
      let authorizer = ScheduleableAlarm.MockAuthorizer()
      authorizer.status = .notDetermined
      authorizer.statusOnRequest = .authorized

      try await withDependencies {
        $0[ScheduleableAlarm.AuthorizerKey.self] = authorizer
        $0[Mountain.LoaderKey.self] = Mountain.MockLoader(result: .success(.mock1))
      } operation: {
        let model = PlanClimbModel(mountainId: Mountain.mock1.id)

        try await model.alarmToggled()
        expectNoDifference(model.alarmsAuthorization, .authorized)
        expectNoDifference(model.shouldAddAlarm, true)
      }
    }

    @Test("Toggles Alarm, Does Not Enable When Permission Denied")
    func togglesAlarmDoesNotEnableWhenPermissionDenied() async throws {
      let authorizer = ScheduleableAlarm.MockAuthorizer()
      authorizer.status = .notDetermined
      authorizer.statusOnRequest = .unauthorized

      try await withDependencies {
        $0[ScheduleableAlarm.AuthorizerKey.self] = authorizer
        $0[Mountain.LoaderKey.self] = Mountain.MockLoader(result: .success(.mock1))
      } operation: {
        let model = PlanClimbModel(mountainId: Mountain.mock1.id)

        try await model.alarmToggled()
        expectNoDifference(model.alarmsAuthorization, .unauthorized)
        expectNoDifference(model.shouldAddAlarm, false)
      }
    }

    @Test("Plan Climb Without Alarm")
    func planClimbWithoutAlarm() async throws {
      let expectedCreate = Mountain.ClimbPlanCreate(
        mountainId: Mountain.mock1.id,
        targetDate: .distantFuture
      )
      try await withDependencies {
        $0[ScheduleableAlarm.AuthorizerKey.self] = ScheduleableAlarm.MockAuthorizer()
        $0[Mountain.LoaderKey.self] = Mountain.MockLoader(result: .success(.mock1))

        let planner = Mountain.MockClimbPlanner()
        planner.setResult(for: expectedCreate, result: .success(.mock1))
        $0[Mountain.PlanClimberKey.self] = planner
      } operation: {
        let model = PlanClimbModel(mountainId: Mountain.mock1.id)
        try await model.$mountain.load()
        model.targetDate = expectedCreate.targetDate

        try await confirmation { confirm in
          model.onPlanned = {
            expectNoDifference($0, .mock1)
            confirm()
          }
          try await model.submitted()
        }
      }
    }

    @Test("Plan Climb With Alarm")
    func planClimbWithAlarm() async throws {
      let authorizer = ScheduleableAlarm.MockAuthorizer()
      authorizer.status = .authorized

      let expectedCreate = Mountain.ClimbPlanCreate(
        mountainId: Mountain.mock1.id,
        targetDate: .distantFuture,
        alarm: Mountain.ClimbPlanCreate.Alarm(
          mountainName: Mountain.mock1.name,
          date: .distantFuture
        )
      )
      try await withDependencies {
        $0[ScheduleableAlarm.AuthorizerKey.self] = authorizer
        $0[Mountain.LoaderKey.self] = Mountain.MockLoader(result: .success(.mock1))

        let planner = Mountain.MockClimbPlanner()
        planner.setResult(for: expectedCreate, result: .success(.mock1))
        $0[Mountain.PlanClimberKey.self] = planner
      } operation: {
        let model = PlanClimbModel(mountainId: Mountain.mock1.id)
        try await model.$mountain.load()
        model.targetDate = expectedCreate.targetDate

        try await model.alarmToggled()
        model.alarmDate = expectedCreate.alarm!.date

        try await confirmation { confirm in
          model.onPlanned = {
            expectNoDifference($0, .mock1)
            confirm()
          }
          try await model.submitted()
        }
      }
    }
  }
}
