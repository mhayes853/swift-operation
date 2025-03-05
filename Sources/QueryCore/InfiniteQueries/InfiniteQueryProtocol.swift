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
    case initialPage
    case allPages
  }
}

extension InfiniteQueryPaging: Equatable where PageValue: Equatable {}
extension InfiniteQueryPaging: Hashable where PageValue: Hashable {}

extension InfiniteQueryPaging.Request: Equatable where PageValue: Equatable {}
extension InfiniteQueryPaging.Request: Hashable where PageValue: Hashable {}

// MARK: - InfiniteQueryResponse

public enum InfiniteQueryValue<PageID: Hashable & Sendable, PageValue: Sendable>: Sendable {
  case allPages(InfiniteQueryPages<PageID, PageValue>)
  case nextPage(NextPage?)
  case previousPage(PreviousPage?)
  case initialPage(InfiniteQueryPage<PageID, PageValue>)
}

extension InfiniteQueryValue {
  public struct NextPage: Sendable {
    public let page: InfiniteQueryPage<PageID, PageValue>
    public let previousPage: InfiniteQueryPage<PageID, PageValue>
  }

  public struct PreviousPage: Sendable {
    public let page: InfiniteQueryPage<PageID, PageValue>
    public let nextPage: InfiniteQueryPage<PageID, PageValue>
  }
}

extension InfiniteQueryValue: Equatable where PageValue: Equatable {}
extension InfiniteQueryValue: Hashable where PageValue: Hashable {}

extension InfiniteQueryValue.NextPage: Hashable where PageValue: Hashable {}
extension InfiniteQueryValue.NextPage: Equatable where PageValue: Equatable {}

extension InfiniteQueryValue.PreviousPage: Hashable where PageValue: Hashable {}
extension InfiniteQueryValue.PreviousPage: Equatable where PageValue: Equatable {}

// MARK: - InfiniteQueryProtocol

public protocol InfiniteQueryProtocol<PageID, PageValue>: QueryProtocol
where
  Value == InfiniteQueryValue<PageID, PageValue>,
  StateValue == InfiniteQueryPages<PageID, PageValue>,
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
    let paging = context.infiniteValues!.paging(for: self)
    switch paging.request {
    case .allPages:
      return try await self.fetchAllPages(using: paging, in: context)
    case .initialPage:
      return try await self.fetchInitialPage(using: paging, in: context)
    case let .nextPageAfter(lastPage):
      return try await self.fetchNextPage(after: lastPage, using: paging, in: context)
    case let .previousPageBefore(firstPage):
      return try await self.fetchPreviousPage(before: firstPage, using: paging, in: context)
    }
  }

  private func fetchAllPages(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) async throws -> Value {
    var newPages = InfiniteQueryPages<PageID, PageValue>(uniqueElements: [])
    var lastPage: InfiniteQueryPage<PageID, PageValue>?
    for _ in 0..<paging.pages.count {
      let pageId =
        if let lastPage {
          self.pageId(
            after: lastPage,
            using: InfiniteQueryPaging(pageId: lastPage.id, pages: newPages, request: .allPages)
          )
        } else {
          paging.pages.first?.id ?? self.initialPageId
        }
      guard let pageId else { return .allPages(newPages) }
      let pageValue = try await self.fetchPage(
        using: InfiniteQueryPaging(pageId: pageId, pages: newPages, request: .allPages),
        in: context
      )
      let page = InfiniteQueryPage(id: pageId, value: pageValue)
      lastPage = page
      newPages.append(page)
    }
    return .allPages(newPages)
  }

  private func fetchInitialPage(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) async throws -> Value {
    let pageValue = try await self.fetchPage(using: paging, in: context)
    return .initialPage(InfiniteQueryPage(id: self.initialPageId, value: pageValue))
  }

  private func fetchNextPage(
    after page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) async throws -> Value {
    let currentPage = page
    guard let nextId = self.pageId(after: currentPage, using: paging) else {
      return .nextPage(nil)
    }
    let pageValue = try await self.fetchPage(
      using: InfiniteQueryPaging(pageId: nextId, pages: paging.pages, request: paging.request),
      in: context
    )
    let page = InfiniteQueryPage(id: nextId, value: pageValue)
    return .nextPage(InfiniteQueryValue.NextPage(page: page, previousPage: currentPage))
  }

  private func fetchPreviousPage(
    before page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) async throws -> Value {
    let currentPage = page
    guard let previousId = self.pageId(before: currentPage, using: paging) else {
      return .previousPage(nil)
    }
    let pageValue = try await self.fetchPage(
      using: InfiniteQueryPaging(pageId: previousId, pages: paging.pages, request: paging.request),
      in: context
    )
    let page = InfiniteQueryPage(id: previousId, value: pageValue)
    return .previousPage(InfiniteQueryValue.PreviousPage(page: page, nextPage: currentPage))
  }
}
