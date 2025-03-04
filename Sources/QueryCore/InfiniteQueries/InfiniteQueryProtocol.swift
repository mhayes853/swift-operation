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
  public let pageId: PageID
  public let pages: InfiniteQueryPages<PageID, PageValue>
  public let request: Request
}

extension InfiniteQueryPaging {
  public enum Request: Sendable {
    case nextPageAfter(InfiniteQueryPage<PageID, PageValue>)
    case previousPageBefore(InfiniteQueryPage<PageID, PageValue>)
    case initialPage(PageID)
    case allPages
  }
}

extension InfiniteQueryPaging: Equatable where PageValue: Equatable {}
extension InfiniteQueryPaging: Hashable where PageValue: Hashable {}

extension InfiniteQueryPaging.Request: Equatable where PageValue: Equatable {}
extension InfiniteQueryPaging.Request: Hashable where PageValue: Hashable {}

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
    switch paging.request {
    case .allPages:
      return paging.pages

    case let .initialPage(id):
      let pageValue = try await self.fetchPage(using: paging, in: context)
      let page = InfiniteQueryPage(id: id, value: pageValue)
      var pages = paging.pages
      pages[id: page.id] = page
      return pages

    case let .nextPageAfter(lastPage):
      guard let nextId = self.pageId(after: lastPage, using: paging) else {
        return paging.pages
      }
      let pageValue = try await self.fetchPage(
        using: InfiniteQueryPaging(
          pageId: nextId,
          pages: paging.pages,
          request: paging.request
        ),
        in: context
      )
      let page = InfiniteQueryPage(id: nextId, value: pageValue)
      return paging.pages + [page]

    case let .previousPageBefore(firstPage):
      guard let previousId = self.pageId(before: firstPage, using: paging) else {
        return paging.pages
      }
      let pageValue = try await self.fetchPage(
        using: InfiniteQueryPaging(
          pageId: previousId,
          pages: paging.pages,
          request: paging.request
        ),
        in: context
      )
      let page = InfiniteQueryPage(id: previousId, value: pageValue)
      return [page] + paging.pages
    }
  }
}
