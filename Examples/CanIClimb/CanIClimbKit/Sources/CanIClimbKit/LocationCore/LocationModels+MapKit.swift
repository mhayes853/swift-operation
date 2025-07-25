import MapKit

// MARK: - MKMapItem

extension MKMapItem {
  public convenience init(coordinate: LocationCoordinate2D) {
    self.init(location: CLLocation(coordinate: coordinate), address: nil)
  }
}
