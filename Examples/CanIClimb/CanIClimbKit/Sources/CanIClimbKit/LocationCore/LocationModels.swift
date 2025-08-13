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

extension LocationCoordinate2D {
  public static let alcatraz = Self(latitude: 37.825858, longitude: -122.422202)
  public static let everest = Self(latitude: 27.9881, longitude: 86.9250)
  public static let mountFuji = Self(latitude: 35.3606, longitude: 138.7273)
}

// MARK: - LocationReading

public struct LocationReading: Hashable, Sendable {
  public var coordinate: LocationCoordinate2D
  public var altitudeAboveSeaLevel: Measurement<UnitLength>

  public init(coordinate: LocationCoordinate2D, altitudeAboveSeaLevel: Measurement<UnitLength>) {
    self.coordinate = coordinate
    self.altitudeAboveSeaLevel = altitudeAboveSeaLevel
  }
}

extension LocationReading {
  public static func mock(
    coordinate: LocationCoordinate2D = .alcatraz,
    altitudeAboveSeaLevel: Measurement<UnitLength> = Measurement(value: 0, unit: .meters)
  ) -> Self {
    LocationReading(coordinate: coordinate, altitudeAboveSeaLevel: altitudeAboveSeaLevel)
  }
}
