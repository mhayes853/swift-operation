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
    case .result(.success(nil)):
      Text("Mountain not found")
    case .result(.failure(let error)):
      if case let mountain?? = self.model.mountain {
        MountainView(model: self.model, mountain: mountain)
      } else {
        RemoteOperationErrorView(error: error) {
          Task { try await self.model.$mountain.fetch() }
        }
      }
    default:
      if case let mountain?? = self.model.mountain {
        MountainView(model: self.model, mountain: mountain)
      } else {
        SpinnerView()
      }
    }
  }
}

// MARK: - MountainView

private struct MountainView: View {
  let model: MountainDetailModel
  let mountain: Mountain

  @State private var hasScrolledPastImage = false

  var body: some View {
    ScrollView {
      VStack {
        MountainImageView(mountain: mountain)
        PlannedClimbsListView(model: self.model.plannedClimbs)
      }
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
  }
}

// MARK: - MountainImageView

private struct MountainImageView: View {
  @SharedQuery<ImageData.Query.State> private var image: ImageData?

  let mountain: Mountain

  @ScaledMetric private var imageGradientStop = 0.2

  init(mountain: Mountain) {
    self.mountain = mountain
    self._image = SharedQuery(ImageData.query(for: mountain.imageURL))
  }

  var body: some View {
    ZStack {
      let text = HStack {
        VStack(alignment: .leading) {
          Text(self.mountain.name)
            .font(.title.bold())
          ElevationLabel(elevation: self.mountain.elevation)
            .foregroundColor(.gray)
        }
        Spacer()
        MountainDifficultyView(difficulty: self.mountain.difficulty)
      }
      .padding()
      .frame(maxHeight: .infinity, alignment: .bottom)

      ImageDataView(url: self.mountain.imageURL) {
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
            text
              .foregroundStyle(.black)
          }
        default:
          ZStack {
            Rectangle()
              .fill(.gray.gradient)
            SpinnerView()
          }
          text
        }
      }
    }
    .frame(height: 300)
    .frame(maxWidth: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .padding()
    .ignoresSafeArea()
  }
}
