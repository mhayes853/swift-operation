import Dependencies
import MapKit

extension Mountain.Location {
  public protocol MapsOpener: Sendable {
    func openDirections(to location: Mountain.Location, for travelType: TravelType) async -> Bool
  }

  public enum MapsOpenerKey: DependencyKey {
    public static let liveValue: any MapsOpener = MKMapsOpener()
  }
}

extension Mountain.Location {
  @MainActor
  public final class MockMapsOpener: MapsOpener {
    public var result = true

    public init() {}

    public func openDirections(
      to location: Mountain.Location,
      for travelType: TravelType
    ) async -> Bool {
      self.result
    }
  }
}
