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

  public init(id: Mountain.ID) {
    self._mountain = SharedQuery(Mountain.query(id: id), animation: .bouncy)
  }
}

// MARK: - MountainDetailView

public struct MountainDetailView: View {
  private var model: MountainDetailModel

  public init(model: MountainDetailModel) {
    self.model = model
  }

  public var body: some View {
    if let mountain = self.model.mountain {
      Text("\(mountain?.name) Details")
    }
  }
}
