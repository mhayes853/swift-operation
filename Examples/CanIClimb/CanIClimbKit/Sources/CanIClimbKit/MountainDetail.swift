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

  public var selectedTab = Tab.mountain

  public init(id: Mountain.ID) {
    self._mountain = SharedQuery(Mountain.query(id: id), animation: .bouncy)
    self.plannedClimbs = PlannedClimbsListModel(mountainId: id)
  }
}

extension MountainDetailModel {
  public enum Tab: Hashable, Sendable {
    case mountain
    case plannedClimbs
  }
}

// MARK: - MountainDetailView

public struct MountainDetailView: View {
  @Bindable private var model: MountainDetailModel

  public init(model: MountainDetailModel) {
    self.model = model
  }

  public var body: some View {
    switch self.model.$mountain.status {
    case .result(.success(let mountain?)):
      VStack {
        Text("\(mountain.name) Details")
        PlannedClimbsListView(model: self.model.plannedClimbs)
      }
    case .result(.success(nil)):
      Text("Mountain not found")
    case .result(.failure(let error)):
      RemoteOperationErrorView(error: error) {
        Task { try await self.model.$mountain.fetch() }
      }
    default:
      SpinnerView()
    }
  }
}
