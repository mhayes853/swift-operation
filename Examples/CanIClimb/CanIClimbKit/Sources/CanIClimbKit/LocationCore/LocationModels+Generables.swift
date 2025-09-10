import FoundationModels

// MARK: - LocationCoordinate2D

extension LocationCoordinate2D {
  @Generable
  public struct Generable: Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
      self.latitude = latitude
      self.longitude = longitude
    }

    public init(coordinate: LocationCoordinate2D) {
      self.latitude = coordinate.latitude
      self.longitude = coordinate.longitude
    }
  }
}

extension LocationCoordinate2D {
  public init(generable: Generable) {
    self.init(latitude: generable.latitude, longitude: generable.longitude)
  }
}

// MARK: - LocationReading

extension LocationReading {
  @Generable
  public struct Generable: Hashable, Sendable {
    @Guide(description: "A lat-lng coordinate.")
    public var coordinate: LocationCoordinate2D.Generable
    public var altitudeAboveSeaLevelMeters: Double

    public init(coordinate: LocationCoordinate2D.Generable, altitudeAboveSeaLevelMeters: Double) {
      self.coordinate = coordinate
      self.altitudeAboveSeaLevelMeters = altitudeAboveSeaLevelMeters
    }

    public init(reading: LocationReading) {
      self.init(
        coordinate: LocationCoordinate2D.Generable(coordinate: reading.coordinate),
        altitudeAboveSeaLevelMeters: reading.altitudeAboveSeaLevel.converted(to: .meters).value
      )
    }
  }
}
