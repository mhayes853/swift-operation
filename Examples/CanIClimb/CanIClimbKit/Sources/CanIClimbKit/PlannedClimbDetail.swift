import Observation
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - PlannedClimbDetailModel

@MainActor
@Observable
public final class PlannedClimbDetailModel {
  @ObservationIgnored
  @SharedQuery<Mountain.Query.State> public var mountain: Mountain??

  @ObservationIgnored
  @SharedQuery(Mountain.achieveClimbMutation) public var achieveClimb: Void?

  @ObservationIgnored
  @SharedQuery(Mountain.unachieveClimbMutation) public var unachieveClimb: Void?

  @ObservationIgnored
  @SharedQuery(Mountain.unplanClimbsMutation) public var unplanClimb: Void?

  @ObservationIgnored public var onUnplanned: (() -> Void)?

  public let plannedClimb: Mountain.PlannedClimb
  public var destination: Destination?

  public init(plannedClimb: Mountain.PlannedClimb) {
    self.plannedClimb = plannedClimb
    self._mountain = SharedQuery(Mountain.query(id: plannedClimb.mountainId), animation: .bouncy)
  }
}

extension PlannedClimbDetailModel {
  @CasePathable
  public enum Destination: Hashable, Sendable {
    case alert(AlertState<AlertAction>)
  }

  public func alert(action: AlertAction?) async throws {

  }

  public func cancelInvoked() {
    guard case let mountain?? = self.mountain else { return }
    self.destination = .alert(
      .confirmUnplanClimb(targetDate: self.plannedClimb.targetDate, mountainName: mountain.name)
    )
  }
}

// MARK: - AlertState

extension PlannedClimbDetailModel {
  public enum AlertAction: Hashable, Sendable {
    case confirmUnplanClimb
  }
}

extension AlertState where Action == PlannedClimbDetailModel.AlertAction {
  public static func confirmUnplanClimb(targetDate: Date, mountainName: String) -> Self {
    Self {
      TextState("Cancel Climb?")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("Cancel")
      }
      ButtonState(role: .destructive, action: .confirmUnplanClimb) {
        TextState("Cancel")
      }
    } message: {
      TextState(
        """
        Are you sure you want to cancel your climb for \(mountainName) on \
        \(targetDate.formatted(date: .abbreviated, time: .omitted)) at \
        \(targetDate.formatted(date: .omitted, time: .shortened))?
        """
      )
    }
  }
}

// MARK: - PlannedClimbDetailView

public struct PlannedClimbDetailView: View {
  private let model: PlannedClimbDetailModel

  public init(model: PlannedClimbDetailModel) {
    self.model = model
  }

  public var body: some View {
    Form {

    }
  }
}
