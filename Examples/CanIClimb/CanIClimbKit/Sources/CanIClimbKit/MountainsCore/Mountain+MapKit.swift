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

// MARK: - MKMapsOpener

extension Mountain.Location {
  public struct MKMapsOpener: MapsOpener {
    public init() {}

    public func openDirections(
      to location: Mountain.Location,
      for travelType: TravelType
    ) async -> Bool {
      let mapItem = MKMapItem(location: location)
      let options = [MKLaunchOptionsDirectionsModeKey: travelType.mkLaunchOptionsDirectionMode]
      return await mapItem.openInMaps(launchOptions: options as [String: Any])
    }
  }
}
