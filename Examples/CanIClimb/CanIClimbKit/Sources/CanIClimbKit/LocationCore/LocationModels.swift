import CoreLocation
import Foundation

// MARK: - LocationCoordinate2D

public struct LocationCoordinate2D: Hashable, Sendable, Codable {
  public var latitude: Double
  public var longitude: Double

  public init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }
}

extension LocationCoordinate2D {
  public init(coordinate: CLLocationCoordinate2D) {
    self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
  }
}

extension CLLocation {
  public convenience init(coordinate: LocationCoordinate2D) {
    self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
  }
}

// MARK: - LocationReading

public struct LocationReading: Sendable {
  public var coordinate: LocationCoordinate2D
  public var altitudeAboveSeaLevel: Measurement<UnitLength>

  public init(coordinate: LocationCoordinate2D, altitudeAboveSeaLevel: Measurement<UnitLength>) {
    self.coordinate = coordinate
    self.altitudeAboveSeaLevel = altitudeAboveSeaLevel
  }
}

extension LocationReading {
  public init(location: CLLocation) {
    self.init(
      coordinate: LocationCoordinate2D(
        latitude: location.coordinate.latitude,
        longitude: location.coordinate.longitude
      ),
      altitudeAboveSeaLevel: Measurement(value: location.altitude, unit: .meters)
    )
  }
}
