import MapKit

// MARK: - MapKitClient

public final class MapKitClient: MapsClient {
  public static let shared = MapKitClient()

  public init() {}

  public func estimate(for request: TravelEstimate.Request) async throws -> TravelEstimate {
    let request = MKDirections.Request(from: request)
    let eta = try await MKDirections(request: request).calculateETA()
    return TravelEstimate(response: eta)
  }

  public func openDirections(
    to location: Mountain.Location,
    for travelType: TravelType
  ) async -> Bool {
    let mapItem = MKMapItem(location: location)
    let options = [MKLaunchOptionsDirectionsModeKey: travelType.mkLaunchOptionsDirectionMode]
    return await mapItem.openInMaps(launchOptions: options as [String: Any])
  }
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
