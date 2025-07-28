import Observation
import SwiftUI
import SwiftUINavigation

// MARK: - MountainDetailModel

@MainActor
@Observable
public final class MountainDetailModel: HashableObject {
  public init(id: Mountain.ID) {
  }
}

// MARK: - MountainDetailView

public struct MountainDetailView: View {
  private var model: MountainDetailModel

  public init(model: MountainDetailModel) {
    self.model = model
  }

  public var body: some View {
    Text("Mountain Detail View")
  }
}
