import Combine
import Dependencies
import MapKit
import Observation
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - MountainTravelEstimatesModel

@MainActor
@Observable
public final class MountainTravelEstimatesModel {
  @ObservationIgnored
  @SharedQuery(LocationReading.userQuery) public var userLocation

  public let mountain: Mountain
  public private(set) var estimates = [TravelType: SharedQuery<TravelEstimate.Query.State>]()
  public var destination: Destination?
  @ObservationIgnored public var onUserLocationChanged: (() -> Void)?
  @ObservationIgnored private var task: Task<Void, Never>?

  @ObservationIgnored
  @Dependency(Mountain.Location.MapsOpenerKey.self) private var opener

  public init(mountain: Mountain) {
    self.mountain = mountain
    let userLocation = self.$userLocation
    self.task = Task { [weak self] in
      for await element in userLocation.states {
        guard let self else { return }
        if let userLocation = element.state.currentValue {
          for type in TravelType.allCases {
            let request = TravelEstimate.Request(
              travelType: type,
              origin: userLocation.coordinate,
              destination: mountain.location.coordinate
            )
            self.estimates[type] = SharedQuery(TravelEstimate.query(for: request))
          }
        } else {
          self.estimates.removeAll()
        }
        self.onUserLocationChanged?()
      }
    }
  }

  public func travelRouteInvoked(for travelType: TravelType) async {
    if !(await self.opener.openDirections(to: self.mountain.location, for: travelType)) {
      self.destination = .alert(.failedToOpenDirections)
    }
  }
}

extension MountainTravelEstimatesModel {
  @CasePathable
  public enum Destination: Hashable {
    case mapItem(MKMapItem)
    case alert(AlertState<AlertAction>)
  }

  public func mapInvoked() {
    self.destination = .mapItem(MKMapItem(location: self.mountain.location))
  }
}

// MARK: - AlertState

extension MountainTravelEstimatesModel {
  public enum AlertAction: Hashable, Sendable {}
}

extension AlertState where Action == MountainTravelEstimatesModel.AlertAction {
  public static let failedToOpenDirections = Self {
    TextState("Failed to Open Directions")
  } message: {
    @Dependency(DeviceInfo.self) var deviceInfo
    return TextState(
      """
      The directions could not be opened. This is likely because you do not have Apple Maps \
      installed on your \(deviceInfo.localizedModelName).
      """
    )
  }
}

// MARK: - MountainTravelEstimatesView

public struct MountainTravelEstimatesView: View {
  @Bindable private var model: MountainTravelEstimatesModel
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  public init(model: MountainTravelEstimatesModel) {
    self.model = model
  }

  public var body: some View {
    VStack(alignment: .leading) {
      MountainLocationNameLabel(name: self.model.mountain.location.name)
        .onTapGesture { self.model.mapInvoked() }
      MapView(model: self.model)
      TravelEstimatesView(model: self.model)
        .padding(.top)
    }
    .mapItemDetailSheet(item: self.$model.destination.mapItem)
    .alert(self.$model.destination.alert) { _ in }
  }
}

// MARK: - MapView

private struct MapView: View {
  let model: MountainTravelEstimatesModel

  var body: some View {
    Map(
      initialPosition: .camera(
        MapCamera(
          centerCoordinate: CLLocationCoordinate2D(
            coordinate: self.model.mountain.location.coordinate
          ),
          distance: 5000
        )
      ),
      interactionModes: .all
    ) {
      Annotation(mountain: self.model.mountain) {
        self.model.mapInvoked()
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 20))
  }
}

// MARK: - TravelEstimatesView

private struct TravelEstimatesView: View {
  let model: MountainTravelEstimatesModel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(TravelType.allCases, id: \.self) { travelType in
        TravelEstimateView(model: self.model, travelType: travelType)
      }
    }
  }
}

// MARK: - TravelEstimateView

private struct TravelEstimateView: View {
  let model: MountainTravelEstimatesModel
  let travelType: TravelType

  @ScaledMetric private var iconSize = CGFloat(40)

  var body: some View {
    Button {
      Task { await self.model.travelRouteInvoked(for: self.travelType) }
    } label: {
      HStack(alignment: .center) {
        Image(systemName: self.travelType.systemImageName)
          .frame(width: self.iconSize, height: self.iconSize)
          .clipShape(RoundedRectangle(cornerRadius: 20))

        let estimate = self.model.estimates[self.travelType]
        if let estimate = estimate?.wrappedValue {
          VStack(alignment: .leading) {
            let formatter = DateComponentsFormatter.travelEstimate(for: estimate.duration)
            Text(formatter.string(from: estimate.duration) ?? "--")
              .font(.headline)
            Text(estimate.distance.formatted())
              .font(.footnote)
              .foregroundStyle(.secondary)
          }

        } else if estimate?.isLoading == true {
          SpinnerView()
        } else {
          Text("--")
            .foregroundStyle(.secondary)
        }

        TappableSpacer()

        Image(systemName: "chevron.right")
          .foregroundStyle(.secondary)
      }
    }
    .buttonStyle(.plain)
  }
}

extension DateComponentsFormatter {
  fileprivate static func travelEstimate(for interval: TimeInterval) -> DateComponentsFormatter {
    interval >= 3600 ? travelEstimateHourMinute : travelEstimateMinute
  }

  private static let travelEstimateMinute: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.minute]
    formatter.unitsStyle = .short
    formatter.maximumUnitCount = 2
    formatter.zeroFormattingBehavior = []
    formatter.collapsesLargestUnit = true
    return formatter
  }()

  private static let travelEstimateHourMinute: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter.travelEstimateMinute
    formatter.allowedUnits = [.hour, .minute]
    return formatter
  }()
}

extension TravelType {
  fileprivate var systemImageName: String {
    switch self {
    case .cycling: "figure.outdoor.cycle"
    case .publicTransport: "bus.fill"
    case .driving: "car.fill"
    case .walking: "figure.walk"
    }
  }
}

#Preview {
  let _ = prepareDependencies {
    struct PreviewEstimater: TravelEstimate.Loader {
      func estimate(for request: TravelEstimate.Request) async throws -> TravelEstimate {
        .mock(for: request.travelType)
      }
    }

    $0[TravelEstimate.LoaderKey.self] = PreviewEstimater()

    let opener = Mountain.Location.MockMapsOpener()
    opener.result = false
    $0[Mountain.Location.MapsOpenerKey.self] = opener

    let userLocation = MockUserLocation()
    userLocation.currentReading = .success(
      LocationReading(
        coordinate: .alcatraz,
        altitudeAboveSeaLevel: Measurement(value: 0, unit: .meters)
      )
    )
    $0[UserLocationKey.self] = userLocation
  }

  let model = MountainTravelEstimatesModel(mountain: .mock1)

  MountainTravelEstimatesView(model: model)
    .frame(height: 500)
    .padding()
}
