import Dependencies
import IdentifiedCollections

extension Mountain {
  public protocol Catalog: Sendable {
    func localSearchMountains(by request: Search) async throws -> IdentifiedArrayOf<Mountain>
    func searchMountains(by request: SearchRequest) async throws -> SearchResult
    func localMountain(with id: Mountain.ID) async throws -> Mountain?
    func mountain(with id: Mountain.ID) async throws -> Mountain?
  }

  public enum CatalogKey: DependencyKey {
    public static var liveValue: any Catalog {
      Mountains.shared
    }
  }
}

extension Mountain {
  @MainActor
  public final class MockCatalog: Catalog {
    public var searchResults = [SearchRequest: Result<SearchResult, any Error>]()
    public var localSearchResults = IdentifiedArrayOf<Mountain>()
    public var mountainResult: Result<Mountain?, any Error>
    public var localMountainResult: Mountain?

    public nonisolated init(mountainResult: Result<Mountain?, any Error> = .success(nil)) {
      self.mountainResult = mountainResult
    }

    public func localSearchMountains(
      by request: Mountain.Search
    ) async throws -> IdentifiedArrayOf<Mountain> {
      self.localSearchResults
    }

    public func searchMountains(by request: SearchRequest) async throws -> SearchResult {
      guard let result = self.searchResults[request] else { throw MissingResultError() }
      return try result.get()
    }

    public func localMountain(with id: Mountain.ID) async throws -> Mountain? {
      self.localMountainResult
    }

    public func mountain(with id: Mountain.ID) async throws -> Mountain? {
      try self.mountainResult.get()
    }

    private struct MissingResultError: Error {}
  }
}
