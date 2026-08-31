import Dependencies
import MapKit
import Operation

// MARK: - Request

extension TravelEstimate {
  public struct Request: Hashable, Sendable {
    public var travelType: TravelType
    public var origin: LocationCoordinate2D
    public var destination: LocationCoordinate2D

    public init(
      travelType: TravelType,
      origin: LocationCoordinate2D,
      destination: LocationCoordinate2D
    ) {
      self.travelType = travelType
      self.origin = origin
      self.destination = destination
    }
  }
}

extension TravelEstimate.Request {
  public static func mock(for travelType: TravelType) -> Self {
    Self(travelType: travelType, origin: .alcatraz, destination: .everest)
  }
}

// MARK: - MapsClient

public protocol MapsClient: Sendable {
  func estimate(for request: TravelEstimate.Request) async throws -> TravelEstimate
  func openDirections(to location: Mountain.Location, for travelType: TravelType) async -> Bool
}

public enum MapsClientKey: DependencyKey {
  public static let liveValue: any MapsClient = MapKitClient.shared
}

@MainActor
public final class MockMapsClient: MapsClient {
  public var estimateResults = [TravelEstimate.Request: Result<TravelEstimate, any Error>]()
  public var openDirectionsResult = true

  public init() {}

  public func estimate(for request: TravelEstimate.Request) async throws -> TravelEstimate {
    guard let result = self.estimateResults[request] else { throw MissingResultError() }
    return try result.get()
  }

  public func openDirections(
    to location: Mountain.Location,
    for travelType: TravelType
  ) async -> Bool {
    self.openDirectionsResult
  }

  private struct MissingResultError: Error {}
}

// MARK: - Query

extension TravelEstimate {
  @QueryRequest
  public static func query(for request: Request) async throws -> TravelEstimate {
    @Dependency(MapsClientKey.self) var maps
    return try await maps.estimate(for: request)
  }
}
