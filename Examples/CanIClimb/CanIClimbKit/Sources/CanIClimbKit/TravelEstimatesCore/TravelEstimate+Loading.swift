import Dependencies
import MapKit
import Query

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

// MARK: - Loader

extension TravelEstimate {
  public protocol Loader: Sendable {
    func estimate(for request: Request) async throws -> TravelEstimate
  }

  public enum LoaderKey: DependencyKey {
    public static let liveValue: any Loader = MapKitLoader.shared
  }
}

// MARK: - Query

extension TravelEstimate {
  public static func query(for request: Request) -> some QueryRequest<Self, Query.State> {
    Query(request: request)
  }

  public struct Query: QueryRequest, Hashable {
    let request: Request

    public func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<TravelEstimate>
    ) async throws -> TravelEstimate {
      @Dependency(TravelEstimate.LoaderKey.self) var loader
      return try await loader.estimate(for: self.request)
    }
  }
}
