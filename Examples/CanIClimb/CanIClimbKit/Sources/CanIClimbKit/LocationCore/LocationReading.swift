import CoreLocation
import Foundation

// MARK: - LocationReading

public struct LocationReading: Sendable {
  public var coordinate: LocationCoordinate2D
  public var altitudeAboveSeaLevel: Measurement<UnitLength>

  public init(coordinate: LocationCoordinate2D, altitudeAboveSeaLevel: Measurement<UnitLength>) {
    self.coordinate = coordinate
    self.altitudeAboveSeaLevel = altitudeAboveSeaLevel
  }
}

// MARK: - CLLocation

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
