import Observation
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - MountainDetailModel

@MainActor
@Observable
public final class MountainDetailModel: HashableObject, Identifiable {
  @ObservationIgnored
  @SharedQuery<Mountain.Query.State> public var mountain: Mountain??

  public var destination: Destination?
  private let mountainId: Mountain.ID

  public init(id: Mountain.ID) {
    self._mountain = SharedQuery(Mountain.query(id: id), animation: .bouncy)
    self.mountainId = id
  }
}

extension MountainDetailModel {
  @CasePathable
  public enum Destination: Hashable, Sendable {
    case planClimb(PlanClimbModel)
  }
}

extension MountainDetailModel {
  public func planClimbInvoked() {
    self.destination = .planClimb(PlanClimbModel(mountainId: self.mountainId))
  }
}

// MARK: - MountainDetailView

public struct MountainDetailView: View {
  @Bindable private var model: MountainDetailModel

  public init(model: MountainDetailModel) {
    self.model = model
  }

  public var body: some View {
    VStack {
      if let mountain = self.model.mountain {
        Text("\(mountain?.name) Details")
      }
      Button("Plan Climb") {
        self.model.planClimbInvoked()
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
