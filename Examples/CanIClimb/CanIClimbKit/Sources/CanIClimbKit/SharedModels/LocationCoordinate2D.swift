// NB: Don't use CLLocationCoordinate2D because it is not Hashable.

public struct LocationCoordinate2D: Hashable, Sendable, Codable {
  public var latitude: Double
  public var longitude: Double

  public init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }
}
