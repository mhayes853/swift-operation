import IdentifiedCollections

// MARK: - InfiniteQueryPage

/// A page of data from an ``InfiniteQueryRequest``.
public struct InfiniteQueryPage<ID: Hashable & Sendable, Value: Sendable>: Sendable, Identifiable {
  /// The unique id of this page.
  public var id: ID

  /// The value of this page.
  public var value: Value

  /// Creates a page.
  ///
  /// - Parameters:
  ///   - id: The unique page id.
  ///   - value: The page value.
  public init(id: ID, value: Value) {
    self.id = id
    self.value = value
  }
}

extension InfiniteQueryPage: Equatable where Value: Equatable {}
extension InfiniteQueryPage: Hashable where Value: Hashable {}

// MARK: - InfiniteQueryPages

/// A helper typealias for ``InfiniteQueryPages`` using a single ``InfiniteQueryRequest`` generic
/// parameter.
public typealias InfiniteQueryPagesFor<Query: InfiniteQueryRequest> =
  InfiniteQueryPages<Query.PageID, Query.PageValue>

/// The data type returned from an ``InfiniteQueryRequest``.
public typealias InfiniteQueryPages<PageID: Hashable & Sendable, PageValue: Sendable> =
  IdentifiedArrayOf<InfiniteQueryPage<PageID, PageValue>>

// MARK: - InfiniteQueryPaging

/// A data type that contains useful info when an ``InfiniteQueryRequest`` is fetching its data.
///
/// You do not create instances of this type. Rather, your ``InfiniteQueryRequest`` receives
/// instances of this type in its requirements.
public struct InfiniteQueryPaging<PageID: Hashable & Sendable, PageValue: Sendable>: Sendable {
  /// The page id that you must perform the required action for in ``InfiniteQueryRequest``.
  public let pageId: PageID

  /// The current list of pages from the query.
  public let pages: InfiniteQueryPages<PageID, PageValue>

  /// The ``InfiniteQueryPagingRequest`` that will be carried out when fetching page data.
  public let request: InfiniteQueryPagingRequest<PageID>
}

extension InfiniteQueryPaging: Equatable where PageValue: Equatable {}
extension InfiniteQueryPaging: Hashable where PageValue: Hashable {}

// MARK: - InfiniteQueryPagingRequest

/// The kind of request that is being performed by an ``InfiniteQueryRequest``.
public enum InfiniteQueryPagingRequest<PageID: Hashable & Sendable>: Hashable, Sendable {
  /// The query is requesting the next page.
  case nextPage(PageID)

  /// The query is requesting the page that will be placed at the beginning of the list.
  case previousPage(PageID)

  /// The query is requesting the initial page.
  case initialPage

  /// The query is requesting that all pages be refetched.
  case allPages
}

// MARK: - InfiniteQueryResponse

/// The data type returned from an ``InfiniteQueryRequest``.
///
/// You do not construct this type, ``InfiniteQueryRequest`` constructs it for you.
public struct InfiniteQueryOperationValue<
  PageID: Hashable & Sendable,
  PageValue: Sendable
>: Sendable {
  /// The value returned from fetching an ``InfiniteQueryRequest``.
  public let fetchValue: FetchValue

  let nextPageId: PageID?
  let previousPageId: PageID?
}

extension InfiniteQueryOperationValue {
  /// A value returned from fetching an ``InfiniteQueryRequest``.
  public enum FetchValue: Sendable {
    /// All pages were refetched.
    case allPages(InfiniteQueryPages<PageID, PageValue>)

    /// The next page was fetched.
    case nextPage(NextPage)

    /// The previous page was fetched.
    case previousPage(PreviousPage)

    /// The initial page was fetched.
    case initialPage(InfiniteQueryPage<PageID, PageValue>)
  }
}

extension InfiniteQueryOperationValue.FetchValue {
  /// Details regarding the next fetched page.
  public struct NextPage: Sendable {
    /// The page that was fetched.
    public let page: InfiniteQueryPage<PageID, PageValue>

    /// The ID of the last page before ``page`` in the pages list.
    public let lastPageId: PageID
  }

  /// Details regarding the page that will be placed at the beginning of the pages list.
  public struct PreviousPage: Sendable {
    /// The page that was fetched.
    public let page: InfiniteQueryPage<PageID, PageValue>

    /// The ID of the first page after ``page`` in the pages list.
    public let firstPageId: PageID
  }
}

extension InfiniteQueryOperationValue: Equatable where PageValue: Equatable {}
extension InfiniteQueryOperationValue: Hashable where PageValue: Hashable {}

extension InfiniteQueryOperationValue.FetchValue: Equatable where PageValue: Equatable {}
extension InfiniteQueryOperationValue.FetchValue: Hashable where PageValue: Hashable {}

extension InfiniteQueryOperationValue.FetchValue.NextPage: Hashable where PageValue: Hashable {}
extension InfiniteQueryOperationValue.FetchValue.NextPage: Equatable where PageValue: Equatable {}

extension InfiniteQueryOperationValue.FetchValue.PreviousPage: Hashable where PageValue: Hashable {}
extension InfiniteQueryOperationValue.FetchValue.PreviousPage: Equatable
where PageValue: Equatable {}

// MARK: - InfiniteQueryRequest

/// A protocol for describing an infinite query.
///
/// Infinite queries are used whenever you're fetching paginated data that may be displayed in an
/// infinitely scrolling list.
///
/// `InfiniteQueryRequest` inherits from ``QueryRequest``, and adds a few additional requirements:
/// 1. Associated types for the page id (ie. the next page token from your API) and the page value (the data you're fetching for each page).
/// 2. The initial page id.
/// 3. Methods to retrieve the next and previous page ids from the first and last pages respectively.
/// 4. A method to fetch the data for a page.
///
/// ```swift
/// extension PostsPage {
///   static func listQuery(
///     for feedId: Int
///   ) -> some InfiniteQueryRequest<String, PostsPage> {
///     FeedQuery(feedId: feedId)
///   }
///
///   struct FeedQuery: InfiniteQueryRequest, Hashable {
///     typealias PageID = String
///     typealias PageValue = PostsPage
///
///     let feedId: Int
///
///     let initialPageId = "initial"
///
///     func pageId(
///       after page: InfiniteQueryPage<String, PostsPage>,
///       using paging: InfiniteQueryPaging<String, PostsPage>,
///       in context: OperationContext
///     ) -> String? {
///       page.value.nextPageToken
///     }
///
///     func fetchPage(
///       using paging: InfiniteQueryPaging<String, PostsPage>,
///       in context: OperationContext,
///       with continuation: OperationContinuation<PostsPage>
///     ) async throws -> PostsPage {
///       try await self.fetchFeedPage(for: paging.pageId)
///     }
///   }
/// }
/// ```
///
/// An infinite query can fetch its data in 4 different ways, and you can inspect
/// ``InfiniteQueryPaging/request`` in your query to find out which way its fetching.
/// 1. Fetching the initial page.
/// 2. Fetching the next page in the list.
///   - This can run concurrently alongside fetching the previous page.
/// 3. Fetching the page in the list that will be placed before the beginning of the list (ie. the previous page).
///   - This can run concurrently alongside fetching the next page.
/// 4. Refetching all existing pages.
///
/// When that state of the query is an empty list of pages, calling
/// ``OperationStore/fetchNextPage(using:handler:)`` or ``OperationStore/fetchPreviousPage(using:handler:)``
///  will fetch the initial page of data. Only subsequent calls to those methods will fetch the
///  next and previous page respectively after the initial page has been fetched.
///
///  ```swift
///  let store = client.store(for: Post.listsQuery(for: 1))
///
///  // Fetches inital page if store.currentValue.isEmpty == true
///  let page = try await store.fetchNextPage()
///  ```
///
///  You can also refetch the entire list of pages, one at a time, by calling ``OperationStore/refetchAllPages(using:handler:)``.
///
///  ```swift
///  let store = client.store(for: Post.listsQuery(for: 1))
///
///  let pages = try await store.fetchAllPages()
///  ```
///
///  After fetching a page, ``InfiniteQueryRequest/pageId(after:using:in:)`` and
///  ``InfiniteQueryRequest/pageId(before:using:in:)`` are called to eagerly calculate whether or
///  not additional pages are available for your query to fetch. You can check
///  ``InfiniteQueryState/nextPageId`` or ``InfiniteQueryState/previousPageId`` to check what the
///  ids of the next and previous available pages for your query. A nil value for either of those
///  properties indicates that there are no additional pages for your query to fetch through
///  ``OperationStore/fetchNextPage(using:handler:)`` and
///  ``OperationStore/fetchPreviousPage(using:handler:)`` respectively. If you just want to check
///  whether or not fetching additional pages is possible, you can check the boolean properties
///  ``InfiniteQueryState/hasNextPage`` or ``InfiniteQueryState/hasPreviousPage``.
public protocol InfiniteQueryRequest<PageID, PageValue, PageFailure>: OperationRequest, Sendable
where
  Value == InfiniteQueryOperationValue<PageID, PageValue>,
  State == InfiniteQueryState<PageID, PageValue, PageFailure>,
  Failure == PageFailure
{
  /// The data type of each page that you're fetching.
  associatedtype PageValue: Sendable

  /// The type to identify the data in a page.
  ///
  /// This is typically the `nextPageToken`/`previousPageToken` from your API, an integer
  /// describing the page index or offset, or a custom cursor type from your API.
  associatedtype PageID: Hashable & Sendable

  associatedtype PageFailure: Error

  /// The id of the initial page to fetch.
  var initialPageId: PageID { get }

  /// Retrieves the page id after the last page in the list.
  ///
  /// If nil is returned, then it is assumed that the query will no longer be fetching pages after
  /// the last page.
  ///
  /// - Parameters:
  ///   - page: The last page in the list.
  ///   - paging: ``InfiniteQueryPaging``.
  ///   - context: The ``OperationContext`` passed to this query.
  /// - Returns: The next page id, or nil if none.
  func pageId(
    after page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext
  ) -> PageID?

  /// Retrieves the page id before the first page in the list.
  ///
  /// If nil is returned, then it is assumed that the query will no longer be fetching pages before
  /// the first page.
  ///
  /// - Parameters:
  ///   - page: The first page in the list.
  ///   - paging: ``InfiniteQueryPaging``.
  ///   - context: The ``OperationContext`` passed to this query.
  /// - Returns: The previous page id, or nil if none.
  func pageId(
    before page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext
  ) -> PageID?

  /// Fetches the data for a specified page.
  ///
  /// - Parameters:
  ///   - paging: The ``InfiniteQueryPaging`` for this operation. You can access the page id to fetch data for via the ``InfiniteQueryPaging/pageId`` property.
  ///   - context: The ``OperationContext`` passed to this query.
  ///   - continuation: A ``OperationContinuation`` allowing you to yield multiple values from your query. See <doc:MultistageQueries> for more.
  /// - Returns: The page value for the page.
  func fetchPage(
    isolation: isolated (any Actor)?,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext,
    with continuation: OperationContinuation<PageValue>
  ) async throws(PageFailure) -> PageValue
}

extension InfiniteQueryRequest {
  public func pageId(
    before page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext
  ) -> PageID? {
    nil
  }

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Value>
  ) async throws(PageFailure) -> Value {
    let paging = context.paging(for: self)
    switch paging.request {
    case .allPages:
      return try await self.fetchAllPages(
        isolation: isolation,
        using: paging,
        in: context,
        with: continuation
      )
    case .initialPage:
      return try await self.fetchInitialPage(
        isolation: isolation,
        using: paging,
        in: context,
        with: continuation
      )
    case .nextPage(let id):
      return try await self.fetchNextPage(
        isolation: isolation,
        with: id,
        using: paging,
        in: context,
        with: continuation
      )
    case .previousPage(let id):
      return try await self.fetchPreviousPage(
        isolation: isolation,
        with: id,
        using: paging,
        in: context,
        with: continuation
      )
    }
  }

  private func fetchAllPages(
    isolation: isolated (any Actor)?,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext,
    with continuation: OperationContinuation<Value>
  ) async throws(PageFailure) -> InfiniteQueryOperationValue<PageID, PageValue> {
    var newPages = context.infiniteValues?.currentPagesTracker?.pages(for: self) ?? []
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
        isolation: isolation,
        using: InfiniteQueryPaging(pageId: pageId, pages: newPages, request: .allPages),
        in: context,
        with: OperationContinuation { [newPages] result, yieldedContext in
          continuation.yield(
            with: result.map {
              var pages = newPages
              pages.append(InfiniteQueryPage(id: pageId, value: $0))
              return self.allPagesValue(pages: pages, paging: paging, in: yieldedContext ?? context)
            },
            using: yieldedContext
          )
        }
      )
      newPages.append(InfiniteQueryPage(id: pageId, value: pageValue))
      context.infiniteValues?.currentPagesTracker?.savePages(newPages)
    }
    return self.allPagesValue(pages: newPages, paging: paging, in: context)
  }

  private func allPagesValue(
    pages: InfiniteQueryPages<PageID, PageValue>,
    paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext
  ) -> Value {
    InfiniteQueryOperationValue(
      fetchValue: .allPages(pages),
      nextPageId: pages.last.flatMap { self.pageId(after: $0, using: paging, in: context) },
      previousPageId: pages.first.flatMap { self.pageId(before: $0, using: paging, in: context) }
    )
  }

  private func fetchInitialPage(
    isolation: isolated (any Actor)?,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext,
    with continuation: OperationContinuation<Value>
  ) async throws(PageFailure) -> InfiniteQueryOperationValue<PageID, PageValue> {
    let pageValue = try await self.fetchPageWithPublishedEvents(
      isolation: isolation,
      using: paging,
      in: context,
      with: OperationContinuation { result, yieldedContext in
        continuation.yield(
          with: result.map {
            self.initialPageValue(pageValue: $0, using: paging, in: yieldedContext ?? context)
          },
          using: yieldedContext
        )
      }
    )
    return self.initialPageValue(pageValue: pageValue, using: paging, in: context)
  }

  private func initialPageValue(
    pageValue: PageValue,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext
  ) -> Value {
    let page = InfiniteQueryPage(id: self.initialPageId, value: pageValue)
    return InfiniteQueryOperationValue(
      fetchValue: .initialPage(page),
      nextPageId: self.pageId(after: page, using: paging, in: context),
      previousPageId: self.pageId(before: page, using: paging, in: context)
    )
  }

  private func fetchNextPage(
    isolation: isolated (any Actor)?,
    with pageId: PageID,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext,
    with continuation: OperationContinuation<Value>
  ) async throws(PageFailure) -> InfiniteQueryOperationValue<PageID, PageValue> {
    let pageValue = try await self.fetchPageWithPublishedEvents(
      isolation: isolation,
      using: InfiniteQueryPaging(pageId: pageId, pages: paging.pages, request: paging.request),
      in: context,
      with: OperationContinuation { result, yieldedContext in
        continuation.yield(
          with: result.map {
            self.nextPageValue(
              pageValue: $0,
              with: pageId,
              using: paging,
              in: yieldedContext ?? context
            )
          },
          using: yieldedContext
        )
      }
    )
    return self.nextPageValue(pageValue: pageValue, with: pageId, using: paging, in: context)
  }

  private func nextPageValue(
    pageValue: PageValue,
    with pageId: PageID,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext
  ) -> Value {
    let page = InfiniteQueryPage(id: pageId, value: pageValue)
    return InfiniteQueryOperationValue(
      fetchValue: .nextPage(
        InfiniteQueryOperationValue.FetchValue.NextPage(
          page: page,
          lastPageId: paging.pages.last!.id
        )
      ),
      nextPageId: self.pageId(after: page, using: paging, in: context),
      previousPageId: paging.pages.first.flatMap {
        self.pageId(before: $0, using: paging, in: context)
      }
    )
  }

  private func fetchPreviousPage(
    isolation: isolated (any Actor)?,
    with pageId: PageID,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext,
    with continuation: OperationContinuation<Value>
  ) async throws(PageFailure) -> InfiniteQueryOperationValue<PageID, PageValue> {
    let pageValue = try await self.fetchPageWithPublishedEvents(
      isolation: isolation,
      using: InfiniteQueryPaging(pageId: pageId, pages: paging.pages, request: paging.request),
      in: context,
      with: OperationContinuation { result, yieldedContext in
        continuation.yield(
          with: result.map {
            self.previousPageValue(
              pageValue: $0,
              with: pageId,
              using: paging,
              in: yieldedContext ?? context
            )
          },
          using: yieldedContext
        )
      }
    )
    return self.previousPageValue(pageValue: pageValue, with: pageId, using: paging, in: context)
  }

  private func previousPageValue(
    pageValue: PageValue,
    with pageId: PageID,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext
  ) -> Value {
    let page = InfiniteQueryPage(id: pageId, value: pageValue)
    return InfiniteQueryOperationValue(
      fetchValue: .previousPage(
        InfiniteQueryOperationValue.FetchValue.PreviousPage(
          page: page,
          firstPageId: paging.pages.first!.id
        )
      ),
      nextPageId: paging.pages.last.flatMap { self.pageId(after: $0, using: paging, in: context) },
      previousPageId: self.pageId(before: page, using: paging, in: context)
    )
  }

  private func fetchPageWithPublishedEvents(
    isolation: isolated (any Actor)?,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext,
    with continuation: OperationContinuation<PageValue>
  ) async throws(PageFailure) -> PageValue {
    let id = AnyHashableSendable(paging.pageId)
    context.infiniteValues?.requestSubscriptions.forEach { $0.onPageFetchingStarted(id, context) }
    let continuation = OperationContinuation<PageValue> { result, yieldedContext in
      var context = yieldedContext ?? context
      context.operationResultUpdateReason = .yieldedResult
      context.infiniteValues?.requestSubscriptions
        .forEach { sub in
          let result = result.map {
            InfiniteQueryPage(id: paging.pageId, value: $0) as any Sendable
          }
          sub.onPageResultReceived(id, result, context)
        }
      continuation.yield(with: result)
    }
    let result = await Result { @Sendable () async throws(PageFailure) in
      try await self.fetchPage(isolation: isolation, using: paging, in: context, with: continuation)
    }

    context.infiniteValues?.requestSubscriptions
      .forEach { sub in
        let result = result.map { InfiniteQueryPage(id: paging.pageId, value: $0) as any Sendable }

        var resultContext = context
        resultContext.operationResultUpdateReason = .returnedFinalResult
        sub.onPageResultReceived(id, result.mapError { $0 }, resultContext)

        sub.onPageFetchingFinished(id, context)
      }
    return try result.get()
  }
}
