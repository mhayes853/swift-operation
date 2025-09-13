import AsyncAlgorithms
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
  @SharedOperation<Mountain.Query.State> public var mountain: Mountain??

  @ObservationIgnored
  @SharedOperation(LocationReading.userQuery) public var userLocation

  @ObservationIgnored
  @SharedOperation<Mountain.ClimbReadiness.GenerationQuery.State>
  public var readiness: Mountain.ClimbReadiness.GeneratedSegment?

  public let plannedClimbs: PlannedClimbsListModel

  public var selectedTab = Tab.mountain

  public private(set) var weather: MountainWeatherModel?
  public private(set) var travelEstimates: MountainTravelEstimatesModel?

  public init(id: Mountain.ID) {
    self._mountain = SharedOperation(Mountain.query(id: id), animation: .bouncy)
    self._readiness = SharedOperation()
    self.plannedClimbs = PlannedClimbsListModel(mountainId: id)
  }

  public func appeared() async {
    for await (e1, e2) in combineLatest(self.$mountain.states, self.$userLocation.states) {
      self.detailsUpdated(mountainStatus: e1.state.status, userLocationStatus: e2.state.status)
    }
  }

  public func detailsUpdated(
    mountainStatus: OperationStatus<Mountain?, any Error>,
    userLocationStatus: OperationStatus<LocationReading, any Error>
  ) {
    switch mountainStatus {
    case .result(.success(let mountain?)):
      if self.weather?.mountain != mountain {
        self.weather = MountainWeatherModel(mountain: mountain)
      }
      if self.travelEstimates?.mountain != mountain {
        self.travelEstimates = MountainTravelEstimatesModel(mountain: mountain)
      }
      self.$readiness = SharedOperation(
        Mountain.ClimbReadiness.generationQuery(for: mountain),
        animation: .default
      )
    case .result(.failure), .result(.success(nil)):
      self.weather = nil
      self.travelEstimates = nil
      self.$readiness = SharedOperation()
    default:
      break
    }

    if case .result(let locationResult) = userLocationStatus {
      self.weather?.userLocationUpdated(reading: locationResult)
      self.travelEstimates?.userLocationUpdated(reading: locationResult)
    }
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
    .task { await self.model.appeared() }
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
          MountainDetailsView(model: self.model, mountain: self.mountain)
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
  @SharedOperation<ImageData.Query.State> private var image: ImageData?

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
        Spacer()
        MountainLocationNameLabel(name: self.mountain.location.name)
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

// MARK: - MountainDetailsView

private struct MountainDetailsView: View {
  @Environment(\.systemLanguageModelAvailability) var appleIntelligenceAvailability

  let model: MountainDetailModel
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
          MountainClimbReadinessView(model: self.model)
        }
      }

      if let weatherModel = self.model.weather {
        MountainDetailSectionView(title: "Weather Comparison") {
          MountainWeatherView(model: weatherModel)
        }
      }

      if let travelEstimatesModel = self.model.travelEstimates {
        MountainDetailSectionView(title: "Directions") {
          MountainTravelEstimatesView(model: travelEstimatesModel)
            .frame(height: self.travelEstimatesSize)
        }
      }
    }
  }
}

// MARK: - MountainClimbReadinessView

private struct MountainClimbReadinessView: View {
  let model: MountainDetailModel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      switch self.model.readiness {
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

      if !self.model.readiness.is(\.full) {
        HStack {
          Spacer()
          SpinnerView()
          Spacer()
        }
      }

      if let lastUpdatedAt = self.model.$readiness.valueLastUpdatedAt {
        Text("Generated on: \(lastUpdatedAt.formatted())")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }
}

extension Mountain.ClimbReadiness.Rating {
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
