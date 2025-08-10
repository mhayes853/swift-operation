import Combine
import MapKit
import Observation
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - MountainDetailTravelEstimatesModel

@MainActor
@Observable
public final class MountainDetailTravelEstimatesModel {
  @ObservationIgnored
  @SharedQuery(LocationReading.userQuery) public var userLocation

  public let location: Mountain.Location
  public private(set) var estimates = [TravelType: SharedQuery<TravelEstimate.Query.State>]()
  public var destination: Destination?
  @ObservationIgnored public var onUserLocationChanged: (() -> Void)?
  @ObservationIgnored private var subscription = QuerySubscription.empty

  public init(location: Mountain.Location) {
    self.location = location
    self.subscription = self.$userLocation.store.subscribe(
      with: QueryEventHandler { [weak self] state, _ in
        Task { @MainActor in
          guard let self else { return }
          if let userLocation = state.currentValue {
            for type in TravelType.allCases {
              let request = TravelEstimate.Request(
                travelType: type,
                origin: userLocation.coordinate,
                destination: location.coordinate
              )
              self.estimates[type] = SharedQuery(TravelEstimate.query(for: request))
            }
          } else {
            self.estimates.removeAll()
          }
          self.onUserLocationChanged?()
        }
      }
    )
  }

  public func travelRouteInvoked(travelType: TravelType) async {
    await self.location.openDirectionsInMaps(travelType: travelType)
  }
}

extension MountainDetailTravelEstimatesModel {
  @CasePathable
  public enum Destination: Hashable {
    case mapItem(MKMapItem)
  }

  public func mapInvoked() {
    self.destination = .mapItem(MKMapItem(location: self.location))
  }
}

// MARK: - MountainDetailTravelEstimatesView

public struct MountainDetailTravelEstimatesView: View {
  private let model: MountainDetailTravelEstimatesModel

  public init(model: MountainDetailTravelEstimatesModel) {
    self.model = model
  }

  public var body: some View {
    EmptyView()
  }
}
