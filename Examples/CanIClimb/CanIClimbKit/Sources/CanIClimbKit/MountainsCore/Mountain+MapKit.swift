import Foundation
import MapKit

// MARK: - MKMapItem

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

// MARK: - Open In Maps

extension Mountain.Location {
  public func openDirectionsInMaps(travelType: TravelType) async {
    await MKMapItem(location: self)
      .openInMaps(
        launchOptions: [MKLaunchOptionsDirectionsModeKey: travelType.mkLaunchOptionsDirectionMode]
      )
  }
}
