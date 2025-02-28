import IdentifiedCollections

// MARK: - InfiniteQueryPage

public struct InfiniteQueryPage<ID: Hashable & Sendable, Value: Sendable>: Sendable, Identifiable {
  public var id: ID
  public var values: [Value]

  public init(id: ID, values: [Value]) {
    self.id = id
    self.values = values
  }
}

extension InfiniteQueryPage: Equatable where Value: Equatable {}
extension InfiniteQueryPage: Hashable where Value: Hashable {}

// MARK: - InfiniteQueryPages

public typealias InfiniteQueryPages<PageID: Hashable & Sendable, PageValue: Sendable> =
  IdentifiedArrayOf<InfiniteQueryPage<PageID, PageValue>>

// MARK: - InfiniteQueryPaging

public struct InfiniteQueryPaging<PageID: Hashable & Sendable, PageValue: Sendable>: Sendable {
  public let currentPageId: PageID
  public let pages: InfiniteQueryPages<PageID, PageValue>

  public init(currentPageId: PageID, pages: InfiniteQueryPages<PageID, PageValue>) {
    self.currentPageId = currentPageId
    self.pages = pages
  }
}

// MARK: - InfiniteQueryProtocol

public protocol InfiniteQueryProtocol<PageID, PageValue>: QueryProtocol {
  associatedtype PageValue: Sendable
  associatedtype PageID: Hashable & Sendable
  associatedtype Value = InfiniteQueryPages<PageID, PageValue>

  var initialPageId: PageID { get }

  func pageId(
    after page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>
  ) -> PageID?

  func pageId(
    before page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>
  ) -> PageID?

  func fetchPage(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) async throws -> PageValue
}

extension InfiniteQueryProtocol {
  public func pageId(
    before page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>
  ) -> PageID? {
    nil
  }

  public func fetch(in context: QueryContext) async throws -> Value {
    fatalError("TODO")
  }
}
