import IdentifiedCollections

// MARK: - InfiniteQueryPage

public struct InfiniteQueryPage<ID: Hashable & Sendable, Value: Sendable>: Sendable, Identifiable {
  public var id: ID
  public var value: Value

  public init(id: ID, value: Value) {
    self.id = id
    self.value = value
  }
}

extension InfiniteQueryPage: Equatable where Value: Equatable {}
extension InfiniteQueryPage: Hashable where Value: Hashable {}

// MARK: - InfiniteQueryPages

public typealias InfiniteQueryPagesFor<Query: InfiniteQueryProtocol> =
  InfiniteQueryPages<Query.PageID, Query.PageValue>

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

public protocol InfiniteQueryProtocol<PageID, PageValue>: QueryProtocol
where
  Value == InfiniteQueryPages<PageID, PageValue>,
  StateValue == Value,
  State == InfiniteQueryState<PageID, PageValue>
{
  associatedtype PageValue: Sendable
  associatedtype PageID: Hashable & Sendable

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
    let paging = context.infiniteValues.paging(for: self)
    switch context.infiniteValues.fetchType {
    case .allPages:
      return paging.pages

    case .currentPage:
      let pageValue = try await self.fetchPage(using: paging, in: context)
      let page = InfiniteQueryPage(id: paging.currentPageId, value: pageValue)
      var pages = paging.pages
      pages[id: page.id] = page
      return pages

    case .nextPage:
      guard let nextId = self.pageId(after: paging.pages.last!, using: paging) else {
        return paging.pages
      }
      let pageValue = try await self.fetchPage(
        using: InfiniteQueryPaging(currentPageId: nextId, pages: paging.pages),
        in: context
      )
      let page = InfiniteQueryPage(id: nextId, value: pageValue)
      return paging.pages + [page]

    case .previousPage:
      guard let previousId = self.pageId(before: paging.pages.first!, using: paging) else {
        return paging.pages
      }
      let pageValue = try await self.fetchPage(
        using: InfiniteQueryPaging(currentPageId: previousId, pages: paging.pages),
        in: context
      )
      let page = InfiniteQueryPage(id: previousId, value: pageValue)
      return [page] + paging.pages
    }
  }
}
