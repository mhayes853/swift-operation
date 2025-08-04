import Foundation
import Observation
import Sharing
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - PlanClimbModel

@MainActor
@Observable
public final class PlanClimbModel: HashableObject, Identifiable {
  @ObservationIgnored
  @SharedQuery<Mountain.Query.State> public var mountain: Mountain??

  @ObservationIgnored
  @SharedReader(.alarmsAuthorization) public var alarmsAuthorization

  @ObservationIgnored
  @SharedQuery(ScheduleableAlarm.requestAuthorizationMutation) public var requestAlarmAuthorization

  @ObservationIgnored
  @SharedQuery(Mountain.planClimbMutation) public var planClimb

  public var targetDate = Date()
  public var alarmDate = Date()

  public private(set) var shouldAddAlarm = false

  @ObservationIgnored public var onPlanned: ((Mountain.PlannedClimb) -> Void)?

  public init(mountainId: Mountain.ID) {
    self._mountain = SharedQuery(Mountain.query(id: mountainId), animation: .bouncy)
  }
}

extension PlanClimbModel {
  public func alarmToggled() async throws {
    guard !self.shouldAddAlarm else {
      self.shouldAddAlarm = false
      return
    }
    guard self.alarmsAuthorization != .authorized else {
      self.shouldAddAlarm = true
      return
    }

    let status = try await self.$requestAlarmAuthorization.mutate()
    self.shouldAddAlarm = status == .authorized
  }
}

extension PlanClimbModel {
  public func submitted() async throws {
    guard case let mountain?? = self.mountain else { return }
    var create = Mountain.ClimbPlanCreate(mountainId: mountain.id, targetDate: self.targetDate)
    if self.shouldAddAlarm {
      create.alarm = Mountain.ClimbPlanCreate.Alarm(
        mountainName: mountain.name,
        date: self.alarmDate
      )
    }
    let (_, plannedClimb) = try await self.$planClimb.mutate(
      with: Mountain.PlanClimbMutation.Arguments(mountain: mountain, create: create)
    )
    self.onPlanned?(plannedClimb)
  }
}

// MARK: - PlanClimbView

public struct PlanClimbView: View {
  @Bindable private var model: PlanClimbModel

  public init(model: PlanClimbModel) {
    self.model = model
  }

  public var body: some View {
    Form {
      Toggle("Add Alarm", isOn: self.$model.isAlarmsToggled.animation())
        .disabled(self.model.$requestAlarmAuthorization.isLoading)
    }
  }
}

extension PlanClimbModel {
  fileprivate var isAlarmsToggled: Bool {
    get { self.shouldAddAlarm }
    set { Task { try await self.alarmToggled() } }
  }
}
