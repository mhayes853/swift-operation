import Dependencies
import MapKit
import Observation
import SharingQuery
import SwiftUI
import SwiftUINavigation

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

  public var destination: Destination?

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

extension MountainsListModel {
  @CasePathable
  public enum Destination: Hashable, Sendable {
    case settings(SettingsModel)
    case mountainDetail(MountainDetailModel)
  }
}

extension MountainsListModel {
  public func settingsInvoked() {
    self.destination = .settings(SettingsModel())
    print("settings")
  }
}

extension MountainsListModel {
  public func mountainDetailInvoked(for id: Mountain.ID) {
    self.destination = .mountainDetail(MountainDetailModel(id: id))
  }
}

// MARK: - MountainsListView

public struct MountainsListView: View {
  @Bindable private var model: MountainsListModel
  @State private var selectedDetent = PresentationDetent.height(300)

  public init(model: MountainsListModel) {
    self.model = model
  }

  public var body: some View {
    MountainsListMapView(model: self.model)
      .sheet(item: self.$model.destination.settings) { model in
        NavigationStack {
          SettingsView(model: model)
        }
      }
      .sheet(isPresented: .constant(true)) {
        MountainsListSheetContentView(
          model: self.model,
          isFullScreen: self.selectedDetent == .large
        )
        .presentationDetents(
          [.height(300), .medium, .large],
          selection: self.$selectedDetent.animation()
        )
        .interactiveDismissDisabled()
        .presentationBackgroundInteraction(.enabled)
      }
  }
}

// MARK: - MountainsMapView

private struct MountainsListMapView: View {
  let model: MountainsListModel

  var body: some View {
    Map(initialPosition: .userLocation(fallback: .automatic)) {
      ForEach(self.model.mountains) { page in
        ForEach(page.value.mountains) { mountain in
          Marker(
            mountain.name,
            image: "mountain.2.fill",
            coordinate: CLLocationCoordinate2D(coordinate: mountain.coordinate)
          )
        }
      }
    }
    .ignoresSafeArea()
  }
}

// MARK: - MountainsListSheetContentView

private struct MountainsListSheetContentView: View {
  @Bindable var model: MountainsListModel
  let isFullScreen: Bool
  
  @ScaledMetric private var searchRowHeight = 40

  var body: some View {
    ScrollView {
      LazyVStack {
        HStack(alignment: .center) {
          MountainsListSearchFieldView(
            text: self.$model.searchText,
            isFullScreen: self.isFullScreen
          )
          .frame(maxHeight: self.searchRowHeight)
          
          
          Button {
            self.model.settingsInvoked()
          } label: {
            Image(systemName: "person.crop.circle")
              .resizable()
              .scaledToFit()
              .frame(height: self.searchRowHeight)
              .foregroundStyle(.black)
              .accessibilityLabel("Profile")
          }
          .buttonStyle(.plain)
        }
        .padding(.vertical)

        Picker("Category", selection: self.$model.category) {
          Text("Recommended").tag(Mountain.Search.Category.recommended)
          Text("Planned Climbs").tag(Mountain.Search.Category.planned)
        }
        .pickerStyle(.segmented)
      }
      .padding()
    }
  }
}

// MARK: - MountainsListSearchFieldView

private struct MountainsListSearchFieldView: View {
  @Binding var text: String
  let isFullScreen: Bool

  var body: some View {
    HStack(alignment: .center) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(Color.black.opacity(0.5))
      TextField(text: self.$text.animation()) {
        Text("Find Mountains")
          .foregroundStyle(Color.black.opacity(0.5))
          .fontWeight(.semibold)
      }
      .foregroundStyle(.black)

      Spacer()

      if !self.text.isEmpty {
        Button {
          self.text = ""
        } label: {
          Image(systemName: "xmark")
            .foregroundStyle(Color.black.opacity(0.5))
            .accessibilityLabel("Clear")
        }
        .buttonStyle(.plain)
      }
    }
    .padding()
    .background(Color.white)
    .clipShape(Capsule())
    .shadow(color: Color.black.opacity(self.isFullScreen ? 0.15 : 0), radius: 15, y: 10)
  }
}

#Preview {
  let _ = prepareDependencies {
    $0.defaultDatabase = try! canIClimbDatabase()

    let searcher = Mountain.MockSearcher()
    searcher.results[.recommended(page: 0)] = .success(
      Mountain.SearchResult(mountains: [.mock1], hasNextPage: false)
    )
    searcher.results[.planned(page: 0)] = .success(
      Mountain.SearchResult(mountains: [.mock2], hasNextPage: false)
    )
    $0[Mountain.SearcherKey.self] = searcher
  }

  let model = MountainsListModel()
  MountainsListView(model: model)
}
