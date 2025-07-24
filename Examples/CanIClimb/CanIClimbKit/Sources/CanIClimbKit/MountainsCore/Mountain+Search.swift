import Dependencies
import SharingQuery

// MARK: - Search

extension Mountain {
  public struct Search: Codable, Hashable, Sendable {
    public var text: String

    public init(text: String) {
      self.text = text
    }
  }
}

extension Mountain.Search {
  public static let recommended = Self(text: "")
}

// MARK: - Searcher

extension Mountain {
  public struct SearchResult: Hashable, Sendable, Codable {
    public let mountains: IdentifiedArrayOf<Mountain>
    public let hasNextPage: Bool

    public init(mountains: IdentifiedArrayOf<Mountain>, hasNextPage: Bool) {
      self.mountains = mountains
      self.hasNextPage = hasNextPage
    }
  }

  public protocol Searcher: Sendable {
    func searchMountains(by query: Search, page: Int) async throws -> SearchResult
  }

  public enum SearcherKey: DependencyKey {
    public static let liveValue: any Mountain.Searcher = CanIClimbAPI.shared
  }
}

extension Mountain {
  @MainActor
  public final class MockSearcher: Searcher {
    public var results = [Int: Result<Mountain.SearchResult, any Error>]()

    public init() {}

    public func searchMountains(
      by query: Mountain.Search,
      page: Int
    ) async throws -> Mountain.SearchResult {
      guard let result = self.results[page] else { throw NoResultError() }
      return try result.get()
    }

    private struct NoResultError: Error {}
  }
}

extension CanIClimbAPI: Mountain.Searcher {}

// MARK: - Query

extension Mountain {
  public static func searchQuery(_ search: Search) -> some InfiniteQueryRequest<Int, SearchResult> {
    SearchQuery(search: search)
  }

  public struct SearchQuery: InfiniteQueryRequest, Hashable {
    public typealias PageValue = Mountain.SearchResult
    public typealias PageID = Int

    let search: Search

    public let initialPageId = 0

    public func pageId(
      after page: InfiniteQueryPage<PageID, PageValue>,
      using paging: InfiniteQueryPaging<PageID, PageValue>,
      in context: QueryContext
    ) -> PageID? {
      page.value.hasNextPage ? page.id + 1 : nil
    }

    public func fetchPage(
      using paging: InfiniteQueryPaging<PageID, PageValue>,
      in context: QueryContext,
      with continuation: QueryContinuation<PageValue>
    ) async throws -> PageValue {
      @Dependency(Mountain.SearcherKey.self) var searcher
      @Dependency(\.defaultQueryClient) var client
      @Dependency(\.defaultDatabase) var database

      do {
        let searchResult = try await searcher.searchMountains(by: self.search, page: paging.pageId)
        client.updateDetailQueries(mountains: searchResult.mountains)
        try await database.write { try Mountain.save(searchResult.mountains, in: $0) }
        return searchResult
      } catch {
        guard context.isLastRetryAttempt else { throw error }
        let mountains = try await database.read { db in
          try Mountain.findAll(matching: self.search.text, in: db)
        }
        continuation.yield(
          Mountain.SearchResult(
            mountains: IdentifiedArray(uniqueElements: mountains),
            hasNextPage: false
          ),
          using: context
        )
        throw error
      }
    }
  }
}

extension QueryClient {
  fileprivate func updateDetailQueries(mountains: some Sequence<Mountain> & Sendable) {
    self.withStores(matching: .mountain, of: Mountain.Query.State.self) { stores, createStore in
      for mountain in mountains {
        if let store = stores[.mountain(with: mountain.id)] {
          store.currentValue = mountain
        } else {
          stores.update(createStore(for: Mountain.query(id: mountain.id), initialValue: mountain))
        }
      }
    }
  }
}
