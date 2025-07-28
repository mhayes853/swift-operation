import Dependencies
import Observation
import SharingQuery
import SwiftUI

// MARK: - MountainsListModel

@MainActor
@Observable
public final class MountainsListModel {
  @ObservationIgnored
  @SharedQuery(Mountain.searchQuery(.recommended)) public var mountains

  public var searchText = "" {
    didSet { self.debounceTask?.schedule() }
  }
  public var category = Mountain.Search.Category.recommended {
    didSet { self.updateMountainsQuery() }
  }

  @ObservationIgnored private var debounceTask: DebounceTask?

  @ObservationIgnored
  @Dependency(\.continuousClock) private var clock

  public init(searchDebounceDuration: Duration = .seconds(0.5)) {
    self.debounceTask = DebounceTask(
      clock: self.clock,
      duration: searchDebounceDuration
    ) { [weak self] in
      await self?.updateMountainsQuery()
    }
  }
}

extension MountainsListModel {
  private func updateMountainsQuery() {
    let search = Mountain.Search(text: self.searchText, category: self.category)
    self.$mountains = SharedQuery(Mountain.searchQuery(search))
  }
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
