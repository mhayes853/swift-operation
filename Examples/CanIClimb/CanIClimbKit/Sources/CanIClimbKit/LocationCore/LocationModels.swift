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
  public static func random() -> Self {
    var generator = SystemRandomNumberGenerator()
    return .random(using: &generator)
  }

  public static func random(using generator: inout some RandomNumberGenerator) -> Self {
    LocationCoordinate2D(
      latitude: .random(in: -90...90, using: &generator),
      longitude: .random(in: -180...180, using: &generator)
    )
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
