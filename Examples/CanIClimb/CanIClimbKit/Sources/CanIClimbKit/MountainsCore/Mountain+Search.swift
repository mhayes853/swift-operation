import Dependencies
import SharingOperation

// MARK: - Search

extension Mountain {
  public struct Search: Hashable, Sendable {
    public static let recommended = Self(text: "", category: .recommended)
    public static let planned = Self(text: "", category: .planned)

    public var text: String
    public var category: Category

    public init(text: String, category: Category = .recommended) {
      self.text = text
      self.category = category
    }
  }
}

extension Mountain.Search {
  public enum Category: Hashable, Sendable {
    case recommended
    case planned
  }
}

// MARK: - SearchRequest

extension Mountain {
  public struct SearchRequest: Hashable, Sendable {
    public static func recommended(page: Int, text: String = "") -> Self {
      Self(search: Mountain.Search(text: text), page: page)
    }

    public static func planned(page: Int, text: String = "") -> Self {
      Self(search: Mountain.Search(text: text, category: .planned), page: page)
    }

    public var search: Search
    public var page: Int

    public init(search: Mountain.Search, page: Int) {
      self.search = search
      self.page = page
    }
  }
}

// MARK: - Search Result

extension Mountain {
  public struct SearchResult: Hashable, Sendable, Codable {
    public let mountains: IdentifiedArrayOf<Mountain>
    public let hasNextPage: Bool

    public init(mountains: IdentifiedArrayOf<Mountain>, hasNextPage: Bool) {
      self.mountains = mountains
      self.hasNextPage = hasNextPage
    }
  }
}

// MARK: - Searcher

extension Mountain {
  public protocol Searcher: Sendable {
    func localSearchMountains(by request: Search) async throws -> IdentifiedArrayOf<Mountain>
    func searchMountains(by request: SearchRequest) async throws -> SearchResult
  }

  public enum SearcherKey: DependencyKey {
    public static var liveValue: any Mountain.Searcher {
      Mountains.shared
    }
  }
}

extension Mountain {
  @MainActor
  public final class MockSearcher: Searcher {
    public var results = [SearchRequest: Result<SearchResult, any Error>]()
    public var localResults = IdentifiedArrayOf<Mountain>()

    public nonisolated init() {}

    public func localSearchMountains(
      by request: Mountain.Search
    ) async throws -> IdentifiedArrayOf<Mountain> {
      self.localResults
    }

    public func searchMountains(
      by request: SearchRequest
    ) async throws -> SearchResult {
      guard let result = self.results[request] else { throw NoResultError() }
      return try result.get()
    }

    private struct NoResultError: Error {}
  }
}

// MARK: - Query

extension Mountain {
  public static func searchQuery(
    _ search: Search
  ) -> some PaginatedRequest<Int, SearchResult, any Error> {
    SearchQuery(search: search)
  }

  public struct SearchQuery: PaginatedRequest, Hashable {
    public typealias PageValue = Mountain.SearchResult
    public typealias PageID = Int

    let search: Search

    public let initialPageId = 0

    public func pageId(
      after page: Page<PageID, PageValue>,
      using paging: Paging<PageID, PageValue>,
      in context: OperationContext
    ) -> PageID? {
      page.value.hasNextPage ? page.id + 1 : nil
    }

    public func fetchPage(
      isolation: isolated (any Actor)?,
      using paging: Paging<PageID, PageValue>,
      in context: OperationContext,
      with continuation: OperationContinuation<PageValue, any Error>
    ) async throws -> PageValue {
      @Dependency(Mountain.SearcherKey.self) var searcher
      @Dependency(\.defaultOperationClient) var client

      do {
        let request = Mountain.SearchRequest(search: self.search, page: paging.pageId)
        let searchResult = try await searcher.searchMountains(by: request)
        client.updateDetailQueries(mountains: searchResult.mountains)
        return searchResult
      } catch {
        guard paging.pageId == self.initialPageId && context.isLastRetryAttempt else { throw error }
        let mountains = try await searcher.localSearchMountains(by: self.search)
        let searchResult = Mountain.SearchResult(
          mountains: IdentifiedArray(uniqueElements: mountains),
          hasNextPage: true
        )
        continuation.yield(searchResult, using: context)
        throw error
      }
    }
  }
}

extension OperationClient {
  fileprivate func updateDetailQueries(mountains: IdentifiedArrayOf<Mountain>) {
    self.withStores(matching: .mountain, of: Mountain.Query.State.self) { stores, createStore in
      for mountain in mountains {
        if let store = stores[.mountain(with: mountain.id)] {
          store.currentValue = mountain
        } else {
          // NB: Creating the store with the initial value does not set valueLastUpdatedAt, which
          // is required for stale detection.
          let store = createStore(for: Mountain.query(id: mountain.id), initialValue: nil)
          store.currentValue = mountain
          stores.update(store)
        }
      }
    }
  }
}
