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
    self.transportType = MKDirectionsTransportType(travelType: request.travelType)
  }
}

// MARK: - ETAResponse

extension TravelEstimate {
  public init(response: MKDirections.ETAResponse) {
    self.init(
      travelType: TravelType(transportType: response.transportType),
      duration: response.expectedTravelTime,
      distance: Measurement(value: response.distance, unit: .meters),
      origin: LocationCoordinate2D(coordinate: response.source.location.coordinate),
      destination: LocationCoordinate2D(coordinate: response.destination.location.coordinate)
    )
  }
}
