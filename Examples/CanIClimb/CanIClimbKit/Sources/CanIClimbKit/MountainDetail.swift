import Observation
import SharingOperation
import SwiftUI
import SwiftUINavigation

#if canImport(ExpandableText)
  import ExpandableText
#endif

// MARK: - MountainDetailModel

@MainActor
@Observable
public final class MountainDetailModel: HashableObject, Identifiable {
  @ObservationIgnored
  @SharedOperation<QueryState<Mountain?, any Error>> public var mountain: Mountain??

  public let plannedClimbs: PlannedClimbsListModel

  public var selectedTab = Tab.mountain

  public init(id: Mountain.ID) {
    self._mountain = SharedOperation(Mountain.query(id: id), animation: .bouncy)
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
    RemoteOperationStateView(self.model.$mountain) { mountain in
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
          MountainDetailsView(mountain: self.mountain)
            .id(self.mountain)
        case .plannedClimbs:
          PlannedClimbsListView(model: self.model.plannedClimbs, mountain: self.mountain)
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
          self.model.plannedClimbs.planClimbInvoked(mountain: self.mountain)
        }
        .padding()
      }
    }
  }
}

// MARK: - MountainImageView

private struct MountainImageView: View {
  @SharedOperation<QueryState<ImageData, any Error>> private var image: ImageData?

  let mountain: Mountain

  @ScaledMetric private var imageGradientStop = 0.2

  init(mountain: Mountain) {
    self.mountain = mountain
    self._image = SharedOperation(ImageData.query(for: mountain.image.url))
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
            MountainImageLabel(mountain: self.mountain)
              .colorScheme(ColorScheme(mountainImageScheme: self.mountain.image.colorScheme))
              .padding()
              .frame(maxHeight: .infinity, alignment: .bottom)

            MountainDifficultyView(difficulty: self.mountain.difficulty)
              .padding()
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          }
        default:
          ZStack {
            Rectangle()
              .fill(.gray.gradient)
            SpinnerView()
          }
          MountainImageLabel(mountain: self.mountain)
            .padding()
            .frame(maxHeight: .infinity, alignment: .bottom)

          MountainDifficultyView(difficulty: self.mountain.difficulty)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
      }
    }
    .frame(height: 300)
    .frame(maxWidth: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: 30))
    .shadow(color: .black.opacity(0.15), radius: 15, y: 10)
    .ignoresSafeArea()
  }
}

// MARK: - MountainDetailLabel

private struct MountainImageLabel: View {
  let mountain: Mountain

  @ScaledMetric private var columnSize = CGFloat(50)

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(self.mountain.name)
          .font(.title.bold())
        HStack(alignment: .center) {
          MountainLocationNameLabel(name: self.mountain.location.name)
          Spacer()
          ElevationLabel(elevation: self.mountain.elevation)
        }
        .foregroundStyle(.secondary)
      }
      .frame(height: self.columnSize)
    }
    .dynamicTypeSize(...(.xxxLarge))
  }
}

// MARK: - MountainDetailsView

private struct MountainDetailsView: View {
  @Environment(\.systemLanguageModelAvailability) var appleIntelligenceAvailability

  let mountain: Mountain

  @ScaledMetric private var travelEstimatesSize = CGFloat(450)

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      MountainDetailSectionView(title: "About") {
        #if canImport(ExpandableText)
          ExpandableText(self.mountain.displayDescription)
        #else
          Text(self.mountain.displayDescription)
        #endif
      }

      if self.appleIntelligenceAvailability == .available {
        MountainDetailSectionView(title: "Climb Readiness") {
          MountainClimbReadinessView(mountain: self.mountain)
        }
      }

      MountainDetailSectionView(title: "Weather Comparison") {
        MountainWeatherView(mountain: self.mountain)
      }

      MountainDetailSectionView(title: "Directions") {
        MountainTravelEstimatesView(mountain: self.mountain)
          .frame(height: self.travelEstimatesSize)
      }
    }
  }
}

// MARK: - MountainClimbReadinessView

private struct MountainClimbReadinessView: View {
  @SharedOperation<QueryState<MountainClimbReadiness.GeneratedSegment, any Error>>
  private var readiness: MountainClimbReadiness.GeneratedSegment?

  init(mountain: Mountain) {
    self._readiness = SharedOperation(
      MountainClimbReadiness.generationQuery(for: mountain),
      animation: .default
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      switch self.readiness {
      case .full(let full):
        Text(full.rating.title).font(.title.bold())
        HStack {
          Text(verbatim: full.insight)
          Spacer()
        }
      case .partial(let partial):
        if let rating = partial.rating {
          Text(rating.title).font(.title.bold())
        }
        if let insight = partial.insight {
          HStack {
            Text(verbatim: insight)
            Spacer()
          }
        }
      default:
        EmptyView()
      }

      if !self.readiness.is(\.full) {
        HStack {
          Spacer()
          SpinnerView()
          Spacer()
        }
      }

      if let lastUpdatedAt = self.$readiness.valueLastUpdatedAt {
        Text("Generated on: \(lastUpdatedAt.formatted())")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }
}

extension MountainClimbReadiness.Rating {
  fileprivate var title: LocalizedStringResource {
    switch self {
    case .notReady: "Not Ready"
    case .partiallyReady: "Partially Ready"
    case .ready: "Ready"
    }
  }
}

// MARK: - MountainDetailSectionView

private struct MountainDetailSectionView<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme

  let title: LocalizedStringKey
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading) {
      Text(self.title)
        .font(.headline)
        .padding(.leading)

      self.content()
        .frame(maxWidth: .infinity)
        .padding()
        .background(
          self.colorScheme == .dark
            ? AnyShapeStyle(Color.secondaryBackground)
            : AnyShapeStyle(.background)
        )
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(
          color: Color.black.opacity(self.colorScheme == .light ? 0.15 : 0),
          radius: 15,
          y: 10
        )
    }
  }
}
