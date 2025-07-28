import CoreLocation

// MARK: - LocationCoordinate2D

extension LocationCoordinate2D {
  public init(coordinate: CLLocationCoordinate2D) {
    self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
  }
}

extension CLLocationCoordinate2D {
  public init(coordinate: LocationCoordinate2D) {
    self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
  }
}

extension CLLocation {
  public convenience init(coordinate: LocationCoordinate2D) {
    self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
  }
}

// MARK: - LocationReading

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
