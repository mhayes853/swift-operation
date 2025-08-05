import Observation
import SwiftUI
import SwiftUINavigation

// MARK: - PlannedClimbsListModel

@MainActor
@Observable
public final class PlannedClimbsListModel {
  public var destination: Destination? {
    didSet { self.bind() }
  }

  public let mountainId: Mountain.ID

  public init(mountainId: Mountain.ID) {
    self.mountainId = mountainId
  }
}

extension PlannedClimbsListModel {
  @CasePathable
  public enum Destination: Hashable, Sendable {
    case planClimb(PlanClimbModel)
  }

  private func bind() {
    switch self.destination {
    case .planClimb(let model):
      model.onPlanned = { [weak self] _ in self?.destination = nil }
    default:
      break
    }
  }
}

extension PlannedClimbsListModel {
  public func planClimbInvoked() {
    self.destination = .planClimb(PlanClimbModel(mountainId: self.mountainId))
  }
}

// MARK: - PlannedClimbsListView

public struct PlannedClimbsListView: View {
  @Bindable private var model: PlannedClimbsListModel

  public init(model: PlannedClimbsListModel) {
    self.model = model
  }

  public var body: some View {
    Button("Plan Climb") {
      self.model.planClimbInvoked()
    }
    .sheet(item: self.$model.destination.planClimb) { model in
      NavigationStack {
        PlanClimbView(model: model)
          .dismissable()
      }
      .presentationDetents([.medium])
      .presentationDragIndicator(.hidden)
    }
  }
}
