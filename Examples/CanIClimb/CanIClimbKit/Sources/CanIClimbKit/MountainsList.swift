import Observation
import SwiftUI

// MARK: - MountainsListModel

@MainActor
@Observable
public final class MountainsListModel {
  public init() {}
}

// MARK: - MountainsListView

public struct MountainsListView: View {
  @Bindable private var model: MountainsListModel

  public init(model: MountainsListModel) {
    self.model = model
  }

  public var body: some View {
    EmptyView()
  }
}
