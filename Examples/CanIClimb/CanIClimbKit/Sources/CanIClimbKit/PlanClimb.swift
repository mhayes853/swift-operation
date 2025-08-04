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

  public var targetDate = Date() {
    didSet {
      guard !self.didSetAlarmDateManually else { return }
      self._alarmDate = self.targetDate
    }
  }
  private var _alarmDate = Date()

  @ObservationIgnored private var didSetAlarmDateManually = false

  public private(set) var shouldAddAlarm = false

  @ObservationIgnored public var onPlanned: ((Mountain.PlannedClimb) -> Void)?

  public init(mountainId: Mountain.ID) {
    self._mountain = SharedQuery(Mountain.query(id: mountainId), animation: .bouncy)
  }
}

extension PlanClimbModel {
  public var alarmDate: Date {
    get { self._alarmDate }
    set {
      self.didSetAlarmDateManually = true
      self._alarmDate = newValue
    }
  }
}

extension PlanClimbModel {
  public func alarmToggled() async throws {
    guard !self.shouldAddAlarm else {
      withAnimation { self.shouldAddAlarm = false }
      return
    }
    guard self.alarmsAuthorization != .authorized else {
      withAnimation { self.shouldAddAlarm = true }
      return
    }

    let status = try await self.$requestAlarmAuthorization.mutate()
    withAnimation { self.shouldAddAlarm = status == .authorized }
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
  private let model: PlanClimbModel

  public init(model: PlanClimbModel) {
    self.model = model
  }

  public var body: some View {
    switch self.model.$mountain.status {
    case .result(.success(let mountain?)):
      PlanClimbFormView(mountain: mountain, model: self.model)
    case .result(.success(nil)):
      ContentUnavailableView("Mountain Not Found", image: "mountain.2.fill")
    case .result(.failure(let error)):
      RemoteOperationErrorView(error: error) {
        Task { try await self.model.$mountain.fetch() }
      }
    default:
      SpinnerView()
    }
  }
}

// MARK: - PlanClimbFormView

private struct PlanClimbFormView: View {
  let mountain: Mountain
  let model: PlanClimbModel

  var body: some View {
    Form {
      TargetDateSectionView(model: self.model)
      AlarmSectionView(model: self.model)
    }
    .safeAreaInset(edge: .bottom) {
      CTAButton("Plan Climb") {
        Task { try await self.model.submitted() }
      }
      .disabled(self.model.$planClimb.isLoading)
      .padding()
    }
    .toolbar {
      #if os(iOS)
        if self.model.$planClimb.isLoading {
          ToolbarItem(placement: .topBarTrailing) {
            SpinnerView()
          }
        }
      #endif
    }
    .inlineNavigationTitle("Plan Climb for \(self.mountain.name)")
  }
}

// MARK: - TargetDateSectionView

private struct TargetDateSectionView: View {
  @Bindable var model: PlanClimbModel

  var body: some View {
    Section {
      DatePicker("Target Date", selection: self.$model.targetDate)
    } header: {
      Text("Target Date")
    } footer: {
      Text("Select the date you plan to climb this mountain.")
    }
  }
}

// MARK: - AlarmSectionView

private struct AlarmSectionView: View {
  @Bindable var model: PlanClimbModel

  var body: some View {
    Section {
      Toggle("Add Alarm", isOn: self.$model.isAddAlarmsToggled.animation())
        .disabled(self.model.$requestAlarmAuthorization.isLoading)
      if self.model.shouldAddAlarm {
        DatePicker("Alarm Date", selection: self.$model.alarmDate, in: ...self.model.targetDate)
      }
    } header: {
      Text("Alarm")
    } footer: {
      switch self.model.alarmsAuthorization {
      case .authorized:
        EmptyView()
      case .unauthorized:
        Text(
          """
          CanIClimb does not have permission to access your device's alarms. You will need to \
          authorize alarm access in settings in order to add an alarm to this planned climb.
          """
        )
      case .notDetermined:
        Text(
          "You will need to authorize CanIClimb to access your device's alarms when toggling this on."
        )
      }
    }
    .disabled(self.model.alarmsAuthorization == .unauthorized)
  }
}

extension PlanClimbModel {
  fileprivate var isAddAlarmsToggled: Bool {
    get { self.shouldAddAlarm }
    set { Task { try await self.alarmToggled() } }
  }
}
