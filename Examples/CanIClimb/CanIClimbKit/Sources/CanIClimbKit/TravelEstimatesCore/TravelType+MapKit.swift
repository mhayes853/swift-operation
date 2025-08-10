import MapKit

// MARK: - DirectionsTransportType

extension MKDirectionsTransportType {
  public init(travelType: TravelType) {
    switch travelType {
    case .driving: self = .automobile
    case .cycling: self = .cycling
    case .walking: self = .walking
    case .publicTransport: self = .transit
    }
  }
}

extension TravelType {
  public init(transportType: MKDirectionsTransportType) {
    switch transportType {
    case .automobile: self = .driving
    case .cycling: self = .cycling
    case .walking: self = .walking
    default: self = .publicTransport
    }
  }
}

// MARK: - LaunchOptionsDirectionMode

extension TravelType {
  public var mkLaunchOptionsDirectionMode: String {
    switch self {
    case .driving: MKLaunchOptionsDirectionsModeDriving
    case .cycling: MKLaunchOptionsDirectionsModeCycling
    case .walking: MKLaunchOptionsDirectionsModeWalking
    case .publicTransport: MKLaunchOptionsDirectionsModeTransit
    }
  }
}
