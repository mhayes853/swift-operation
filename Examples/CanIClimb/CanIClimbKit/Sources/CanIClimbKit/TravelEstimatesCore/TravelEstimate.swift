import Foundation

public struct TravelEstimate: Hashable, Sendable {
  public var travelType: TravelType
  public var duration: TimeInterval
  public var distance: Measurement<UnitLength>
  public var origin: LocationCoordinate2D
  public var destination: LocationCoordinate2D

  public init(
    travelType: TravelType,
    duration: TimeInterval,
    distance: Measurement<UnitLength>,
    origin: LocationCoordinate2D,
    destination: LocationCoordinate2D
  ) {
    self.travelType = travelType
    self.duration = duration
    self.distance = distance
    self.origin = origin
    self.destination = destination
  }
}
