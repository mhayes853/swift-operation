import Observation
import SharingOperation
import SwiftUI
import SwiftUINavigation

// MARK: - PlannedClimbDetailModel

@MainActor
@Observable
public final class PlannedClimbDetailModel: HashableObject, Identifiable {
  @ObservationIgnored
  @SharedOperation<QueryState<Mountain?, any Error>> public var mountain: Mountain??

  @ObservationIgnored
  @SharedOperation(Mountain.$achieveClimbMutation) public var achieveClimb: Void?

  @ObservationIgnored
  @SharedOperation(Mountain.$unachieveClimbMutation) public var unachieveClimb: Void?

  @ObservationIgnored
  @SharedOperation(Mountain.unplanClimbsMutation) public var unplanClimb: Void?

  @ObservationIgnored public var onUnplanned: (() -> Void)?

  @ObservationIgnored
  @SharedReader public var plannedClimb: Mountain.PlannedClimb

  public var destination: Destination?

  public init(plannedClimb: SharedReader<Mountain.PlannedClimb>) {
    self._plannedClimb = plannedClimb
    self._mountain = SharedOperation(
      Mountain.query(id: plannedClimb.wrappedValue.mountainId),
      animation: .bouncy
    )
  }
}

extension PlannedClimbDetailModel {
  @CasePathable
  public enum Destination: Hashable, Sendable {
    case alert(AlertState<AlertAction>)
  }

  public func alert(action: AlertAction?) async throws {
    switch action {
    case .confirmUnplanClimb:
      guard case let mountain?? = self.mountain else { return }
      try await self.$unplanClimb.mutate(
        with: Mountain.UnplanClimbsArguments(
          mountainId: mountain.id,
          ids: [self.plannedClimb.id]
        )
      )
      self.onUnplanned?()
    default:
      break
    }
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
        TextState("Go Back")
      }
      ButtonState(role: .destructive, action: .confirmUnplanClimb) {
        TextState("Cancel Climb")
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
  @Bindable private var model: PlannedClimbDetailModel

  public init(model: PlannedClimbDetailModel) {
    self.model = model
  }

  public var body: some View {
    RemoteOperationStateView(self.model.$mountain) { mountain in
      if let mountain {
        DetailView(model: self.model, mountain: mountain)
      } else {
        Text("Mountain not found")
      }
    }
    .alert(self.$model.destination.alert) { action in
      Task { try await self.model.alert(action: action) }
    }
  }
}

// MARK: - DetailView

private struct DetailView: View {
  @Environment(\.colorScheme) private var colorScheme

  let model: PlannedClimbDetailModel
  let mountain: Mountain

  var body: some View {
    ScrollView {
      PlannedMountainClimbCardView(plannedClimb: self.model.plannedClimb)
        .padding()
    }
    .toolbar {
      #if os(iOS)
        if self.model.$unplanClimb.isLoading {
          ToolbarItem(placement: .topBarTrailing) {
            SpinnerView()
          }
        }
      #endif
    }
    .safeAreaInset(edge: .bottom) {
      VStack {
        if self.model.plannedClimb.achievedDate != nil {
          CTAButton(
            "Mark Incomplete",
            systemImage: "medal",
            tint: .secondaryBackground,
            foregroundStyle: self.colorScheme == .dark
              ? AnyShapeStyle(.white)
              : AnyShapeStyle(.black)
          ) {
            Task {
              try await self.model.$unachieveClimb.mutate(
                with: Mountain.UnachieveClimbArguments(
                  id: self.model.plannedClimb.id,
                  mountainId: self.mountain.id
                )
              )
            }
          }
        } else {
          CTAButton("Mark Complete", systemImage: "medal.fill") {
            Task {
              try await self.model.$achieveClimb.mutate(
                with: Mountain.AchieveClimbArguments(
                  id: self.model.plannedClimb.id,
                  mountainId: self.mountain.id
                )
              )
            }
          }
        }
        CTAButton("Cancel Climb", tint: .red, foregroundStyle: AnyShapeStyle(.white)) {
          self.model.cancelInvoked()
        }
      }
      .disabled(self.model.$unplanClimb.isLoading)
      .padding()
    }
    .inlineNavigationTitle("Climb for \(self.mountain.name)")
  }
}
