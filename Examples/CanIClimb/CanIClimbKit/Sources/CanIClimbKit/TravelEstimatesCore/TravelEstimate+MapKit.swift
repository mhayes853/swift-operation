import MapKit

// MARK: - MapKitLoader

extension TravelEstimate {
  public final class MapKitLoader: Loader {
    public init() {}

    public func estimate(for request: TravelEstimate.Request) async throws -> TravelEstimate {
      let request = MKDirections.Request(from: request)
      let eta = try await MKDirections(request: request).calculateETA()
      return TravelEstimate(response: eta)
    }
  }
}

extension TravelEstimate.MapKitLoader {
  public static let shared = TravelEstimate.MapKitLoader()
}

// MARK: - DirectionsRequest

extension MKDirections.Request {
  public convenience init(from request: TravelEstimate.Request) {
    self.init()
    self.source = MKMapItem(coordinate: request.origin)
    self.destination = MKMapItem(coordinate: request.destination)
    self.transportType = MKDirectionsTransportType(kind: request.kind)
  }
}

// MARK: - DirectionsTransportType

extension MKDirectionsTransportType {
  public init(kind: TravelEstimate.Kind) {
    switch kind {
    case .driving: self = .automobile
    case .cycling: self = .cycling
    case .walking: self = .walking
    case .publicTransport: self = .transit
    }
  }
}

extension TravelEstimate.Kind {
  public init(transportType: MKDirectionsTransportType) {
    switch transportType {
    case .automobile: self = .driving
    case .cycling: self = .cycling
    case .walking: self = .walking
    default: self = .publicTransport
    }
  }
}

// MARK: - ETAResponse

extension TravelEstimate {
  public init(response: MKDirections.ETAResponse) {
    self.init(
      kind: Kind(transportType: response.transportType),
      duration: response.expectedTravelTime,
      distance: Measurement(value: response.distance, unit: .meters),
      origin: LocationCoordinate2D(coordinate: response.source.location.coordinate),
      destination: LocationCoordinate2D(coordinate: response.destination.location.coordinate)
    )
  }
}
