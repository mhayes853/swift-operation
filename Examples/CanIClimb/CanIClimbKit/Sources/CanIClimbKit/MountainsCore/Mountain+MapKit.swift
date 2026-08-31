import Foundation
import MapKit

// MARK: - Create Maps Item

extension MKMapItem {
  public convenience init(location: Mountain.Location) {
    self.init(
      location: CLLocation(coordinate: location.coordinate),
      address: MKAddress(
        fullAddress: String(localized: location.name.localizedStringResource),
        shortAddress: nil
      )
    )
  }
}
