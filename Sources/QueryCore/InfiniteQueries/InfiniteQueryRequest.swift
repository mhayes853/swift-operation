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

public typealias InfiniteQueryPagesFor<Query: InfiniteQueryRequest> =
  InfiniteQueryPages<Query.PageID, Query.PageValue>

public typealias InfiniteQueryPages<PageID: Hashable & Sendable, PageValue: Sendable> =
  IdentifiedArrayOf<InfiniteQueryPage<PageID, PageValue>>

// MARK: - InfiniteQueryPaging

public struct InfiniteQueryPaging<PageID: Hashable & Sendable, PageValue: Sendable>: Sendable {
  public let pageId: PageID
  public let pages: InfiniteQueryPages<PageID, PageValue>
  public let request: InfiniteQueryPagingRequest<PageID>
}

extension InfiniteQueryPaging: Equatable where PageValue: Equatable {}
extension InfiniteQueryPaging: Hashable where PageValue: Hashable {}

// MARK: - InfiniteQueryPagingRequest

public enum InfiniteQueryPagingRequest<PageID: Hashable & Sendable>: Hashable, Sendable {
  case nextPage(PageID)
  case previousPage(PageID)
  case initialPage
  case allPages
}

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

// MARK: - InfiniteQueryRequest

public protocol InfiniteQueryRequest<PageID, PageValue>: QueryRequest
where
  Value == InfiniteQueryValue<PageID, PageValue>,
  State == InfiniteQueryState<PageID, PageValue>
{
  associatedtype PageValue: Sendable
  associatedtype PageID: Hashable & Sendable

  var initialPageId: PageID { get }

  func pageId(
    after page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) -> PageID?

  func pageId(
    before page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) -> PageID?

  func fetchPage(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext,
    with continuation: QueryContinuation<PageValue>
  ) async throws -> PageValue
}

extension InfiniteQueryRequest {
  public func pageId(
    before page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) -> PageID? {
    nil
  }

  public func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value {
    let paging = context.paging(for: self)
    switch paging.request {
    case .allPages:
      return try await self.fetchAllPages(using: paging, in: context, with: continuation)
    case .initialPage:
      return try await self.fetchInitialPage(using: paging, in: context, with: continuation)
    case let .nextPage(id):
      return try await self.fetchNextPage(with: id, using: paging, in: context, with: continuation)
    case let .previousPage(id):
      return try await self.fetchPreviousPage(
        with: id,
        using: paging,
        in: context,
        with: continuation
      )
    }
  }

  private func fetchAllPages(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> InfiniteQueryValue<PageID, PageValue> {
    var newPages = context.infiniteValues.currentPagesTracker?.pages(for: self) ?? []
    for _ in 0..<paging.pages.count {
      let pageId =
        if let lastPage = newPages.last {
          self.pageId(
            after: lastPage,
            using: InfiniteQueryPaging(pageId: lastPage.id, pages: newPages, request: .allPages),
            in: context
          )
        } else {
          paging.pages.first?.id ?? self.initialPageId
        }
      guard let pageId else {
        return self.allPagesValue(pages: newPages, paging: paging, in: context)
      }
      let pageValue = try await self.fetchPageWithPublishedEvents(
        using: InfiniteQueryPaging(pageId: pageId, pages: newPages, request: .allPages),
        in: context,
        with: QueryContinuation { [newPages] result in
          continuation.yield(
            with: result.map {
              var pages = newPages
              pages.append(InfiniteQueryPage(id: pageId, value: $0))
              return self.allPagesValue(pages: pages, paging: paging, in: context)
            }
          )
        }
      )
      newPages.append(InfiniteQueryPage(id: pageId, value: pageValue))
      context.infiniteValues.currentPagesTracker?.savePages(newPages)
    }
    return self.allPagesValue(pages: newPages, paging: paging, in: context)
  }

  private func allPagesValue(
    pages: InfiniteQueryPages<PageID, PageValue>,
    paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) -> Value {
    InfiniteQueryValue(
      nextPageId: pages.last.flatMap { self.pageId(after: $0, using: paging, in: context) },
      previousPageId: pages.first.flatMap { self.pageId(before: $0, using: paging, in: context) },
      response: .allPages(pages)
    )
  }

  private func fetchInitialPage(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> InfiniteQueryValue<PageID, PageValue> {
    let pageValue = try await self.fetchPageWithPublishedEvents(
      using: paging,
      in: context,
      with: QueryContinuation { result in
        continuation.yield(
          with: result.map { self.initialPageValue(pageValue: $0, using: paging, in: context) }
        )
      }
    )
    return self.initialPageValue(pageValue: pageValue, using: paging, in: context)
  }

  private func initialPageValue(
    pageValue: PageValue,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) -> Value {
    let page = InfiniteQueryPage(id: self.initialPageId, value: pageValue)
    return InfiniteQueryValue(
      nextPageId: self.pageId(after: page, using: paging, in: context),
      previousPageId: self.pageId(before: page, using: paging, in: context),
      response: .initialPage(page)
    )
  }

  private func fetchNextPage(
    with pageId: PageID,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> InfiniteQueryValue<PageID, PageValue> {
    let pageValue = try await self.fetchPageWithPublishedEvents(
      using: InfiniteQueryPaging(pageId: pageId, pages: paging.pages, request: paging.request),
      in: context,
      with: QueryContinuation { result in
        continuation.yield(
          with: result.map {
            self.nextPageValue(pageValue: $0, with: pageId, using: paging, in: context)
          }
        )
      }
    )
    return self.nextPageValue(pageValue: pageValue, with: pageId, using: paging, in: context)
  }

  private func nextPageValue(
    pageValue: PageValue,
    with pageId: PageID,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) -> Value {
    let page = InfiniteQueryPage(id: pageId, value: pageValue)
    return InfiniteQueryValue(
      nextPageId: self.pageId(after: page, using: paging, in: context),
      previousPageId: paging.pages.first.flatMap {
        self.pageId(before: $0, using: paging, in: context)
      },
      response: .nextPage(InfiniteQueryValue.NextPage(page: page, lastPage: paging.pages.last!))
    )
  }

  private func fetchPreviousPage(
    with pageId: PageID,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> InfiniteQueryValue<PageID, PageValue> {
    let pageValue = try await self.fetchPageWithPublishedEvents(
      using: InfiniteQueryPaging(pageId: pageId, pages: paging.pages, request: paging.request),
      in: context,
      with: QueryContinuation { result in
        continuation.yield(
          with: result.map {
            self.previousPageValue(pageValue: $0, with: pageId, using: paging, in: context)
          }
        )
      }
    )
    return self.previousPageValue(pageValue: pageValue, with: pageId, using: paging, in: context)
  }

  private func previousPageValue(
    pageValue: PageValue,
    with pageId: PageID,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) -> Value {
    let page = InfiniteQueryPage(id: pageId, value: pageValue)
    return InfiniteQueryValue(
      nextPageId: paging.pages.last.flatMap { self.pageId(after: $0, using: paging, in: context) },
      previousPageId: self.pageId(before: page, using: paging, in: context),
      response: .previousPage(
        InfiniteQueryValue.PreviousPage(page: page, firstPage: paging.pages.first!)
      )
    )
  }

  private func fetchPageWithPublishedEvents(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext,
    with continuation: QueryContinuation<PageValue>
  ) async throws -> PageValue {
    let id = AnyHashableSendable(paging.pageId)
    context.infiniteValues.subscriptions.forEach { sub in
      sub.onPageFetchingStarted?(id, context)
    }
    let continuation = QueryContinuation<PageValue> { result in
      context.infiniteValues.subscriptions.forEach { sub in
        sub.onPageResultReceived?(id, result.map { InfiniteQueryPage(id: id, value: $0) }, context)
      }
      continuation.yield(with: result)
    }
    let result = await Result {
      try await self.fetchPage(using: paging, in: context, with: continuation)
    }
    context.infiniteValues.subscriptions.forEach { sub in
      sub.onPageResultReceived?(id, result.map { InfiniteQueryPage(id: id, value: $0) }, context)
      sub.onPageFetchingFinished?(id, context)
    }
    return try result.get()
  }
}
