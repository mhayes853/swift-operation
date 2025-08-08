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
    RemoteQueryStateView(self.model.$mountain) { mountain in
      if let mountain {
        MountainDetailScrollView(model: self.model, mountain: mountain)
      } else {
        ContentUnavailableView("Mountain not found", systemImage: "mountain.2.fill")
      }
    }
  }
}

// MARK: - MountainView

private struct MountainDetailScrollView: View {
  @Bindable var model: MountainDetailModel
  let mountain: Mountain

  @State private var hasScrolledPastImage = false

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        MountainImageView(mountain: self.mountain)

        Picker("Mountain or Planned Climbs", selection: self.$model.selectedTab.animation()) {
          Label("Mountain", systemImage: "mountain.2.fill")
            .tag(MountainDetailModel.Tab.mountain)
          Label("Planned Climbs", systemImage: "figure.climbing")
            .tag(MountainDetailModel.Tab.plannedClimbs)
        }
        .pickerStyle(.segmented)

        switch self.model.selectedTab {
        case .mountain:
          Text("Mountain Stuffs")
        case .plannedClimbs:
          PlannedClimbsListView(model: self.model.plannedClimbs)
        }
      }
      .padding()
    }
    .onScrollGeometryChange(for: Bool.self) { geometry in
      geometry.contentOffset.y > geometry.contentInsets.top + 150
    } action: { _, hasScrolled in
      withAnimation(.easeInOut(duration: 0.2)) {
        self.hasScrolledPastImage = hasScrolled
      }
    }
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text(self.mountain.name)
          .font(.headline)
          .opacity(self.hasScrolledPastImage ? 1 : 0)
      }
    }
    .safeAreaInset(edge: .bottom) {
      if self.model.selectedTab == .plannedClimbs {
        CTAButton("Plan New Climb", systemImage: "plus") {
          self.model.plannedClimbs.planClimbInvoked()
        }
        .padding()
      }
    }
  }
}

// MARK: - MountainImageView

private struct MountainImageView: View {
  @SharedQuery<ImageData.Query.State> private var image: ImageData?

  let mountain: Mountain

  @ScaledMetric private var imageGradientStop = 0.2

  init(mountain: Mountain) {
    self.mountain = mountain
    self._image = SharedQuery(ImageData.query(for: mountain.image.url))
  }

  var body: some View {
    ZStack {
      ImageDataView(url: self.mountain.image.url) {
        switch $0 {
        case .result(.success(let image)):
          GeometryReader { proxy in
            image
              .resizable()
              .scaledToFill()
              .frame(width: proxy.size.width)
            image
              .resizable()
              .scaledToFill()
              .frame(width: proxy.size.width)
              .blur(radius: 10)
              .offset(y: 10)
              .background(.ultraThinMaterial)
              .mask(
                LinearGradient(
                  stops: [
                    Gradient.Stop(color: .white, location: 0),
                    Gradient.Stop(color: .white, location: self.imageGradientStop),
                    Gradient.Stop(color: .clear, location: 1)
                  ],
                  startPoint: .bottom,
                  endPoint: .top
                )
              )
            MountainDetailLabel(mountain: self.mountain)
              .colorScheme(ColorScheme(mountainImageScheme: self.mountain.image.colorScheme))
              .padding()
              .frame(maxHeight: .infinity, alignment: .bottom)
          }
        default:
          ZStack {
            Rectangle()
              .fill(.gray.gradient)
            SpinnerView()
          }
          MountainDetailLabel(mountain: self.mountain)
            .padding()
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
      }
    }
    .frame(height: 300)
    .frame(maxWidth: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .shadow(color: .black.opacity(0.15), radius: 15, y: 10)
    .ignoresSafeArea()
  }
}

private struct MountainDetailLabel: View {
  let mountain: Mountain

  @ScaledMetric private var columnSize = CGFloat(50)

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(self.mountain.name)
          .font(.title.bold())
        Spacer()
        MountainLocationNameLabel(name: self.mountain.locationName)
          .foregroundStyle(.secondary)
      }
      .frame(height: self.columnSize)
      Spacer()
      VStack(alignment: .center) {
        MountainDifficultyView(difficulty: self.mountain.difficulty)
        Spacer()
        ElevationLabel(elevation: self.mountain.elevation)
          .foregroundColor(.secondary)
      }
      .frame(height: self.columnSize)
    }
    .dynamicTypeSize(...(.xxxLarge))
  }
}
