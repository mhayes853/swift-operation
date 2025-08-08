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
    self._plannedClimbs = SharedQuery(
      Mountain.plannedClimbsQuery(for: mountainId),
      animation: .bouncy
    )
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
    LazyVStack(spacing: 10) {
      switch self.model.$plannedClimbs.status {
      case .result(.failure(let error)):
        if let climbs = self.model.plannedClimbs {
          ListView(model: model, climbs: climbs)
        } else {
          RemoteOperationErrorView(error: error) {
            Task { try await self.model.$plannedClimbs.fetch() }
          }
        }
      default:
        if let climbs = self.model.plannedClimbs {
          ListView(model: model, climbs: climbs)
        } else {
          SpinnerView()
        }
      }
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

// MARK: - ListView

private struct ListView: View {
  let model: PlannedClimbsListModel
  let climbs: IdentifiedArrayOf<Mountain.PlannedClimb>

  public var body: some View {
    if self.climbs.isEmpty {
      ContentUnavailableView(
        "No Planned Climbs",
        systemImage: "exclamationmark.circle",
        description: Text("Get started by planning your first climb!")
      )
    } else {
      ForEach(self.climbs) { climb in
        PlannedMountainClimbCardView(plannedClimb: climb)
      }
    }
  }
}
