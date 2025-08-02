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

  public var targetDate = Date()
  public var alarmDate = Date()

  public private(set) var shouldAddAlarm = false

  public init(mountainId: Mountain.ID) {
    self._mountain = SharedQuery(Mountain.query(id: mountainId))
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
