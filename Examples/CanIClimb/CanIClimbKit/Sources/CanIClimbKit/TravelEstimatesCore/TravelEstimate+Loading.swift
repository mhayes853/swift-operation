import Dependencies
import Query

// MARK: - Loader

extension TravelEstimate {
  public struct Request: Hashable, Sendable {
    public var kind: Kind
    public var origin: LocationCoordinate2D
    public var destination: LocationCoordinate2D

    public init(kind: Kind, origin: LocationCoordinate2D, destination: LocationCoordinate2D) {
      self.kind = kind
      self.origin = origin
      self.destination = destination
    }
  }

  public protocol Loader: Sendable {
    func estimate(for request: Request) async throws -> TravelEstimate
  }

  public enum LoaderKey: DependencyKey {
    public static let liveValue: any Loader = MapKitLoader()
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
