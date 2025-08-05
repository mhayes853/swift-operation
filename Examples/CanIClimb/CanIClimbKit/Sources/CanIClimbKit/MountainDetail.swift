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

  public let plannedClimbs: PlannedClimbsListModel

  public init(id: Mountain.ID) {
    self._mountain = SharedQuery(Mountain.query(id: id), animation: .bouncy)
    self.plannedClimbs = PlannedClimbsListModel(mountainId: id)
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
      if case let mountain?? = self.model.mountain {
        Text("\(mountain.name) Details")
      }
      PlannedClimbsListView(model: self.model.plannedClimbs)
    }
  }
}
