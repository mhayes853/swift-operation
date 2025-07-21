import Dependencies
import SharingQuery

// MARK: - Search

extension Mountain {
  public struct Search: RawRepresentable, Codable, Hashable, Sendable {
    public var rawValue: String

    public init(rawValue: String) {
      self.rawValue = rawValue
    }
  }
}

extension Mountain.Search {
  public static let all = Self(rawValue: "")
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
      return try await searcher.searchMountains(by: self.search, page: paging.pageId)
    }
  }
}
