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
      MountainView(model: self.model, mountain: mountain)
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
        Rectangle()
          .frame(height: 1200)
      }
    }
    .onScrollGeometryChange(for: Bool.self) { geometry in
      geometry.contentOffset.y > geometry.contentInsets.top + 150
    } action: { _, hasScrolled in
      withAnimation(.easeInOut(duration: 0.2)) {
        self.hasScrolledPastImage = hasScrolled
      }
    }
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
        Text(self.mountain.name)
          .font(.title.bold())
        Spacer()
      }
      .padding()
      .frame(maxHeight: .infinity, alignment: .bottom)

      ImageDataView(url: self.mountain.imageURL) {
        switch $0 {
        case .result(.success(let image)):
          image
            .resizable()
            .scaledToFill()
          image
            .resizable()
            .scaledToFill()
            .blur(radius: 10)
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
    .ignoresSafeArea()
  }
}
