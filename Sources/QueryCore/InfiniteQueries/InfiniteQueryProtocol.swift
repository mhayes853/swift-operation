import ConcurrencyExtras
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
    case nextPage(PageID)
    case previousPage(PageID)
    case initialPage
    case allPages
  }
}

extension InfiniteQueryPaging: Equatable where PageValue: Equatable {}
extension InfiniteQueryPaging: Hashable where PageValue: Hashable {}

extension InfiniteQueryPaging.Request: Equatable where PageValue: Equatable {}
extension InfiniteQueryPaging.Request: Hashable where PageValue: Hashable {}

// MARK: - InfiniteQueryResponse

public struct InfiniteQueryValue<PageID: Hashable & Sendable, PageValue: Sendable>: Sendable {
  public let nextPageId: PageID?
  public let previousPageId: PageID?
  public let response: Response
}

extension InfiniteQueryValue {
  public enum Response: Sendable {
    case allPages(InfiniteQueryPages<PageID, PageValue>)
    case nextPage(NextPage?)
    case previousPage(PreviousPage?)
    case initialPage(InfiniteQueryPage<PageID, PageValue>)
  }
}

extension InfiniteQueryValue {
  public struct NextPage: Sendable {
    public let page: InfiniteQueryPage<PageID, PageValue>
    public let lastPage: InfiniteQueryPage<PageID, PageValue>
  }

  public struct PreviousPage: Sendable {
    public let page: InfiniteQueryPage<PageID, PageValue>
    public let firstPage: InfiniteQueryPage<PageID, PageValue>
  }
}

extension InfiniteQueryValue: Equatable where PageValue: Equatable {}
extension InfiniteQueryValue: Hashable where PageValue: Hashable {}

extension InfiniteQueryValue.Response: Equatable where PageValue: Equatable {}
extension InfiniteQueryValue.Response: Hashable where PageValue: Hashable {}

extension InfiniteQueryValue.NextPage: Hashable where PageValue: Hashable {}
extension InfiniteQueryValue.NextPage: Equatable where PageValue: Equatable {}

extension InfiniteQueryValue.PreviousPage: Hashable where PageValue: Hashable {}
extension InfiniteQueryValue.PreviousPage: Equatable where PageValue: Equatable {}

// MARK: - InfiniteQueryProtocol

public protocol InfiniteQueryProtocol<PageID, PageValue>: QueryProtocol
where
  Value == InfiniteQueryValue<PageID, PageValue>,
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
    let paging = context.paging(for: self)
    switch paging.request {
    case .allPages:
      return try await self.fetchAllPages(using: paging, in: context)
    case .initialPage:
      return try await self.fetchInitialPage(using: paging, in: context)
    case let .nextPage(id):
      return try await self.fetchNextPage(with: id, using: paging, in: context)
    case let .previousPage(id):
      return try await self.fetchPreviousPage(with: id, using: paging, in: context)
    }
  }

  private func fetchAllPages(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) async throws -> InfiniteQueryValue<PageID, PageValue> {
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
      guard let pageId else {
        return InfiniteQueryValue(
          nextPageId: newPages.last.flatMap { self.pageId(after: $0, using: paging) },
          previousPageId: newPages.first.flatMap { self.pageId(before: $0, using: paging) },
          response: .allPages(newPages)
        )
      }
      let pageValue = try await self.fetchPageWithPublishedEvents(
        using: InfiniteQueryPaging(pageId: pageId, pages: newPages, request: .allPages),
        in: context
      )
      let page = InfiniteQueryPage(id: pageId, value: pageValue)
      lastPage = page
      newPages.append(page)
    }
    return InfiniteQueryValue(
      nextPageId: newPages.last.flatMap { self.pageId(after: $0, using: paging) },
      previousPageId: newPages.first.flatMap { self.pageId(before: $0, using: paging) },
      response: .allPages(newPages)
    )
  }

  private func fetchInitialPage(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) async throws -> InfiniteQueryValue<PageID, PageValue> {
    let pageValue = try await self.fetchPageWithPublishedEvents(using: paging, in: context)
    let page = InfiniteQueryPage(id: self.initialPageId, value: pageValue)
    return InfiniteQueryValue(
      nextPageId: self.pageId(after: page, using: paging),
      previousPageId: self.pageId(before: page, using: paging),
      response: .initialPage(page)
    )
  }

  private func fetchNextPage(
    with pageId: PageID,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) async throws -> InfiniteQueryValue<PageID, PageValue> {
    let pageValue = try await self.fetchPageWithPublishedEvents(
      using: InfiniteQueryPaging(pageId: pageId, pages: paging.pages, request: paging.request),
      in: context
    )
    let page = InfiniteQueryPage(id: pageId, value: pageValue)
    return InfiniteQueryValue(
      nextPageId: self.pageId(after: page, using: paging),
      previousPageId: paging.pages.first.flatMap { self.pageId(before: $0, using: paging) },
      response: .nextPage(InfiniteQueryValue.NextPage(page: page, lastPage: paging.pages.last!))
    )
  }

  private func fetchPreviousPage(
    with pageId: PageID,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) async throws -> InfiniteQueryValue<PageID, PageValue> {
    let pageValue = try await self.fetchPageWithPublishedEvents(
      using: InfiniteQueryPaging(pageId: pageId, pages: paging.pages, request: paging.request),
      in: context
    )
    let page = InfiniteQueryPage(id: pageId, value: pageValue)
    return InfiniteQueryValue(
      nextPageId: paging.pages.last.flatMap { self.pageId(after: $0, using: paging) },
      previousPageId: self.pageId(before: page, using: paging),
      response: .previousPage(
        InfiniteQueryValue.PreviousPage(page: page, firstPage: paging.pages.first!)
      )
    )
  }

  private func fetchPageWithPublishedEvents(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) async throws -> PageValue {
    let id = AnyHashableSendable(paging.pageId)
    context.infiniteValues.subscriptions.forEach { sub in
      sub.onPageFetchingStarted?(id, context)
    }
    let result = await Result { try await self.fetchPage(using: paging, in: context) }
    context.infiniteValues.subscriptions.forEach { sub in
      sub.onPageResultReceived?(id, result.map { InfiniteQueryPage(id: id, value: $0) }, context)
      sub.onPageFetchingFinished?(id, context)
    }
    return try result.get()
  }
}

// MARK: - QueryStore

extension InfiniteQueryProtocol {
  public func currentInfiniteStore(in context: QueryContext) -> InfiniteQueryStoreFor<Self>? {
    self.currentQueryStore(in: context).map { InfiniteQueryStore(store: $0) }
  }
}
