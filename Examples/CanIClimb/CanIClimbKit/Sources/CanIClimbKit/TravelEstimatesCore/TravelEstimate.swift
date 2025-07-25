import Foundation

// MARK: - TravelEstimate

public struct TravelEstimate: Hashable, Sendable {
  public var kind: Kind
  public var duration: TimeInterval
  public var distance: Measurement<UnitLength>
  public var origin: LocationCoordinate2D
  public var destination: LocationCoordinate2D

  public init(
    kind: TravelEstimate.Kind,
    duration: TimeInterval,
    distance: Measurement<UnitLength>,
    origin: LocationCoordinate2D,
    destination: LocationCoordinate2D
  ) {
    self.kind = kind
    self.duration = duration
    self.distance = distance
    self.origin = origin
    self.destination = destination
  }
}

// MARK: - Kind

extension TravelEstimate {
  public enum Kind: Hashable, Sendable {
    case walking
    case driving
    case cycling
    case publicTransport
  }
}
