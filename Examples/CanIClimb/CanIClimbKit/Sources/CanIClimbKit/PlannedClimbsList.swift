import IdentifiedCollections
import Observation
import SharingQuery
import SwiftUI
import SwiftUINavigation
import Tagged
import UUIDV7

// MARK: - PlannedClimbsListModel

@MainActor
@Observable
public final class PlannedClimbsListModel {
  @ObservationIgnored
  @SharedQuery<Mountain.PlannedClimbsQuery.State>
  public var plannedClimbs: IdentifiedArrayOf<Mountain.PlannedClimb>?

  public var destination: Destination? {
    didSet { self.bind() }
  }

  public let mountainId: Mountain.ID

  public init(mountainId: Mountain.ID) {
    self.mountainId = mountainId
    self._plannedClimbs = SharedQuery(Mountain.plannedClimbsQuery(for: mountainId))
  }
}

extension PlannedClimbsListModel {
  @CasePathable
  public enum Destination: Hashable, Sendable {
    case planClimb(PlanClimbModel)
  }

  public func planClimbInvoked() {
    self.destination = .planClimb(PlanClimbModel(mountainId: self.mountainId))
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

// MARK: - PlannedClimbsListView

public struct PlannedClimbsListView: View {
  @Bindable private var model: PlannedClimbsListModel

  public init(model: PlannedClimbsListModel) {
    self.model = model
  }

  public var body: some View {
    Text("Planned Climbs")
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
