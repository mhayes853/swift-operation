import Dependencies
import MapKit
import Observation
import SharingOperation
import SwiftUI
import SwiftUINavigation

// MARK: - MountainTravelEstimatesModel

@MainActor
@Observable
public final class MountainTravelEstimatesModel {
  public let mountain: Mountain
  public var destination: Destination?

  @ObservationIgnored
  @Dependency(MapsClientKey.self) private var maps

  public init(mountain: Mountain) {
    self.mountain = mountain
  }

  public func travelRouteInvoked(for travelType: TravelType) async {
    if !(await self.maps.openDirections(to: self.mountain.location, for: travelType)) {
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
  @SharedOperation(LocationReading.userQuery) private var userLocation
  @Bindable private var model: MountainTravelEstimatesModel

  public init(mountain: Mountain) {
    self.model = MountainTravelEstimatesModel(mountain: mountain)
  }

  public var body: some View {
    VStack(alignment: .leading) {
      MountainLocationNameLabel(name: self.model.mountain.location.name)
        .foregroundStyle(.secondary)
        .bold()
        .onTapGesture { self.model.mapInvoked() }
      MapView(model: self.model)
      TravelEstimatesView(model: self.model, userLocation: self.currentUserLocation)
        .padding(.top)
    }
    .mapItemDetailSheet(item: self.$model.destination.mapItem)
    .alert(self.$model.destination.alert) { _ in }
  }

  private var currentUserLocation: LocationReading? {
    switch self.$userLocation.status {
    case .result(.success(let location)):
      location
    case .loading:
      self.userLocation
    default:
      nil
    }
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
      interactionModes: []
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
  let userLocation: LocationReading?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let userLocation = self.userLocation {
        ForEach(TravelType.allCases, id: \.self) { travelType in
          let request = TravelEstimate.Request(
            travelType: travelType,
            origin: userLocation.coordinate,
            destination: self.model.mountain.location.coordinate
          )
          TravelEstimateView(model: self.model, request: request)
            .id(request)
        }
      } else {
        ForEach(TravelType.allCases, id: \.self) { travelType in
          TravelEstimateView(model: self.model, travelType: travelType)
        }
      }
    }
  }
}

// MARK: - TravelEstimateView

private struct TravelEstimateView: View {
  @SharedOperation<QueryState<TravelEstimate, any Error>> private var estimate: TravelEstimate?

  let model: MountainTravelEstimatesModel
  let travelType: TravelType

  @ScaledMetric private var iconSize = CGFloat(40)

  init(model: MountainTravelEstimatesModel, request: TravelEstimate.Request) {
    self.model = model
    self.travelType = request.travelType
    self._estimate = SharedOperation(TravelEstimate.$query(for: request))
  }

  init(model: MountainTravelEstimatesModel, travelType: TravelType) {
    self.model = model
    self.travelType = travelType
    self._estimate = SharedOperation()
  }

  var body: some View {
    Button {
      Task { await self.model.travelRouteInvoked(for: self.travelType) }
    } label: {
      HStack(alignment: .center) {
        Image(systemName: self.travelType.systemImageName)
          .frame(width: self.iconSize, height: self.iconSize)
          .clipShape(RoundedRectangle(cornerRadius: 20))

        if let estimate = self.estimate {
          VStack(alignment: .leading) {
            let formatter = DateComponentsFormatter.travelEstimate(for: estimate.duration)
            Text(formatter.string(from: estimate.duration) ?? "--")
              .font(.headline)
            Text(estimate.distance.formatted())
              .font(.footnote)
              .foregroundStyle(.secondary)
          }

        } else if self.$estimate.isLoading {
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
    let maps = MockMapsClient()
    for travelType in TravelType.allCases {
      maps.estimateResults[.mock(for: travelType)] = .success(.mock(for: travelType))
    }
    maps.openDirectionsResult = false
    $0[MapsClientKey.self] = maps

    let userLocation = MockUserLocation()
    userLocation.currentReading = .success(
      LocationReading(
        coordinate: .alcatraz,
        altitudeAboveSeaLevel: Measurement(value: 0, unit: .meters)
      )
    )
    $0[UserLocationKey.self] = userLocation
  }

  MountainTravelEstimatesView(mountain: .mock1)
    .frame(height: 500)
    .padding()
}
