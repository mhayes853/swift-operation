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

// MARK: - Loader

extension TravelEstimate {
  public protocol Loader: Sendable {
    func estimate(for request: Request) async throws -> TravelEstimate
  }

  public enum LoaderKey: DependencyKey {
    public static let liveValue: any Loader = MapKitLoader.shared
  }
}

extension TravelEstimate {
  @MainActor
  public final class MockLoader: Loader {
    public var results = [Request: Result<TravelEstimate, any Error>]()

    public init() {}

    public func estimate(for request: Request) async throws -> TravelEstimate {
      guard let result = self.results[request] else { throw SomeError() }
      return try result.get()
    }

    private struct SomeError: Error {}
  }
}

// MARK: - Query

extension TravelEstimate {
  @QueryRequest
  public static func query(for request: Request) async throws -> TravelEstimate {
    @Dependency(TravelEstimate.LoaderKey.self) var loader
    return try await loader.estimate(for: request)
  }
}
