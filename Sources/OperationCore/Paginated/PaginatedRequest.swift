import IdentifiedCollections

// MARK: - PaginatedPage

/// A page of data from a ``PaginatedRequest``.
public struct Page<ID: Hashable & Sendable, Value: Sendable>: Sendable, Identifiable {
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

extension Page: Equatable where Value: Equatable {}
extension Page: Hashable where Value: Hashable {}

// MARK: - PaginatedPages

/// A helper typealias for ``Pages`` using a single ``PaginatedRequest`` generic parameter.
public typealias PagesFor<Query: PaginatedRequest> =
  Pages<Query.PageID, Query.PageValue>

/// The data type returned from an ``PaginatedRequest``.
public typealias Pages<PageID: Hashable & Sendable, PageValue: Sendable> =
  IdentifiedArrayOf<Page<PageID, PageValue>>

// MARK: - PaginatedPaging

/// A data type that contains useful info when a method requirement of ``PaginatedRequest`` is
/// invoked.
///
/// You do not create instances of this type. Rather, your ``PaginatedRequest`` receives
/// instances of this type in its method requirements.
public struct Paging<PageID: Hashable & Sendable, PageValue: Sendable>: Sendable {
  /// The page id that you must perform the required action for in ``PaginatedRequest``.
  public let pageId: PageID

  /// The current list of pages from the query.
  public let pages: Pages<PageID, PageValue>

  /// The ``PagingRequest`` that will be carried out when fetching page data.
  public let request: PagingRequest<PageID>
}

extension Paging: Equatable where PageValue: Equatable {}
extension Paging: Hashable where PageValue: Hashable {}

// MARK: - PaginatedPagingRequest

/// The kind of data fetching request that is being performed by n ``PaginatedRequest``.
public enum PagingRequest<PageID: Hashable & Sendable>: Hashable, Sendable {
  /// Requesting to fetch the next page.
  case nextPage(PageID)

  /// Requesting to fetch the page that will be placed at the beginning of the list.
  case previousPage(PageID)

  /// Requesting to fetch the initial page.
  case initialPage

  /// Requesting that all pages be refetched.
  case allPages
}

// MARK: - PaginatedResponse

/// The data type returned from a ``PaginatedRequest``.
///
/// You do not construct this type, ``PaginatedRequest`` constructs it for you.
public struct PaginatedOperationValue<PageID: Hashable & Sendable, PageValue: Sendable>: Sendable {
  /// The value returned from running a ``PaginatedRequest``.
  public let runValue: RunValue

  var nextPageId = PageIDResult.deferred
  var previousPageId = PageIDResult.deferred
}

extension PaginatedOperationValue {
  enum PageIDResult: Hashable, Sendable {
    case computed(PageID?)
    case deferred
  }
}

extension PaginatedOperationValue {
  /// A value returned from running a ``PaginatedRequest``.
  public enum RunValue: Sendable {
    /// All pages were refetched.
    case allPages(Pages<PageID, PageValue>)

    /// The next page was fetched.
    case nextPage(NextPage)

    /// The page placed at the beginning of the pages list was fetched.
    case previousPage(PreviousPage)

    /// The initial page was fetched.
    case initialPage(Page<PageID, PageValue>)
  }
}

extension PaginatedOperationValue.RunValue {
  /// Details regarding the next fetched page.
  public struct NextPage: Sendable {
    /// The page that was fetched.
    public let page: Page<PageID, PageValue>

    /// The ID of the last page before ``page`` in the pages list.
    public let lastPageId: PageID
  }

  /// Details regarding the page that will be placed at the beginning of the pages list.
  public struct PreviousPage: Sendable {
    /// The page that was fetched.
    public let page: Page<PageID, PageValue>

    /// The ID of the first page after ``page`` in the pages list.
    public let firstPageId: PageID
  }
}

extension PaginatedOperationValue: Equatable where PageValue: Equatable {}
extension PaginatedOperationValue: Hashable where PageValue: Hashable {}

extension PaginatedOperationValue.RunValue: Equatable where PageValue: Equatable {}
extension PaginatedOperationValue.RunValue: Hashable where PageValue: Hashable {}

extension PaginatedOperationValue.RunValue.NextPage: Hashable where PageValue: Hashable {}
extension PaginatedOperationValue.RunValue.NextPage: Equatable where PageValue: Equatable {}

extension PaginatedOperationValue.RunValue.PreviousPage: Hashable where PageValue: Hashable {}
extension PaginatedOperationValue.RunValue.PreviousPage: Equatable
where PageValue: Equatable {}

// MARK: - PaginatedRequest

/// A protocol for describing an operation that paginates its data.
///
/// Paginated requests are used whenever you're fetching paginated data that may be displayed in an
/// infinitely scrolling list.
///
/// `PaginatedRequest` inherits from ``StatefulOperationRequest``, and adds a few additional
/// requirements.
/// 1. Associated types for the page id (typically the next page token from your API) and the page
/// value (the data you're fetching for each page).
/// 2. The initial page id.
/// 3. Methods to retrieve the next and previous page ids from the first and last pages respectively.
/// 4. A method to fetch the data for a page.
///
/// ```swift
/// extension PostsPage {
///   static func listQuery(
///     for feedId: Int
///   ) -> some PaginatedRequest<String, PostsPage, any Error> {
///     FeedQuery(feedId: feedId)
///   }
///
///   struct FeedQuery: PaginatedRequest, Hashable {
///     typealias PageID = String
///     typealias PageValue = PostsPage
///
///     let feedId: Int
///
///     let initialPageId = "initial"
///
///     func pageId(
///       after page: PaginatedPage<String, PostsPage>,
///       using paging: PaginatedPaging<String, PostsPage>,
///       in context: OperationContext
///     ) -> String? {
///       page.value.nextPageToken
///     }
///
///     func fetchPage(
///       isolation: isolated (any Actor)?,
///       using paging: PaginatedPaging<String, PostsPage>,
///       in context: OperationContext,
///       with continuation: OperationContinuation<PostsPage, any Error>
///     ) async throws -> PostsPage {
///       try await self.fetchFeedPage(for: paging.pageId)
///     }
///   }
/// }
/// ```
///
/// A paginated operation can fetch its data in 4 different ways, and you can inspect
/// ``Paging/request`` to find out how its fetching.
/// 1. Fetching the initial page.
/// 2. Fetching the next page in the list.
///   - This can run concurrently alongside fetching the previous page.
/// 3. Fetching the page in the list that will be placed before the beginning of the list (ie. the previous page).
///   - This can run concurrently alongside fetching the next page.
/// 4. Refetching all existing pages.
///
/// When that state of the operation is an empty list of pages, calling
/// ``OperationStore/fetchNextPage(using:handler:)`` or ``OperationStore/fetchPreviousPage(using:handler:)``
///  will fetch the initial page of data. Only subsequent calls to those methods will fetch the
///  next and previous page respectively after the initial page has been fetched.
///
///  ```swift
///  let store = client.store(for: Post.listsQuery(for: 1))
///
///  // Fetches inital page if 'store.currentValue.isEmpty == true'.
///  // Otherwise, it will fetch the next page in the list.
///  let page = try await store.fetchNextPage()
///  ```
///
///  You can also refetch the entire list of pages, one at a time, by calling
///  ``OperationStore/refetchAllPages(using:handler:)``. This will refetch all existing pages in a
///  waterfall effect, starting from the first page, and then continuing until either the last
///  known page is refetched, or until no more pages can be fetched.
///
///  ```swift
///  let store = client.store(for: Post.listsQuery(for: 1))
///
///  let pages = try await store.refetchAllPages()
///  ```
///
///  After fetching a page, ``PaginatedRequest/pageId(after:using:in:)`` and
///  ``PaginatedRequest/pageId(before:using:in:)`` are called to eagerly calculate whether or
///  not additional pages are available for your operation to fetch. You can check
///  ``PaginatedState/nextPageId`` or ``PaginatedState/previousPageId`` to check what the
///  ids of the next and previous available pages for your operation. If you just want to check
///  whether or not fetching additional pages is possible, you can check the boolean properties
///  ``PaginatedState/hasNextPage`` or ``PaginatedState/hasPreviousPage``.
///
///  Ideally, paginated operations should not edit data on any remote or external services they
///  utilze. ``MutationRequest`` is more suitable for such edits.
public protocol PaginatedRequest<PageID, PageValue, PageFailure>: StatefulOperationRequest
where
  Value == PaginatedOperationValue<PageID, PageValue>,
  State == PaginatedState<PageID, PageValue, PageFailure>,
  Failure == PageFailure
{
  /// The data type of each page that you're fetching.
  associatedtype PageValue: Sendable

  /// The type to identify the data in a page.
  ///
  /// This is often the `nextPageToken`/`previousPageToken` from an HTTP API, an integer
  /// describing the page index or offset, or a custom cursor type.
  associatedtype PageID: Hashable & Sendable

  /// The error type thrown when fetching page data.
  associatedtype PageFailure: Error

  /// The id of the initial page to fetch.
  var initialPageId: PageID { get }

  /// Retrieves the page id after the last page in the list.
  ///
  /// If nil is returned, then it is assumed that the operation will no longer be fetching pages after
  /// the last page.
  ///
  /// - Parameters:
  ///   - page: The last page in the list.
  ///   - paging: ``Paging``.
  ///   - context: The ``OperationContext`` passed to this operation.
  /// - Returns: The next page id, or nil if none.
  func pageId(
    after page: Page<PageID, PageValue>,
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext
  ) -> PageID?

  /// Retrieves the page id before the first page in the list.
  ///
  /// If nil is returned, then it is assumed that the operation will no longer be fetching pages before
  /// the first page.
  ///
  /// - Parameters:
  ///   - page: The first page in the list.
  ///   - paging: ``Paging``.
  ///   - context: The ``OperationContext`` passed to this operation.
  /// - Returns: The previous page id, or nil if none.
  func pageId(
    before page: Page<PageID, PageValue>,
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext
  ) -> PageID?

  /// Fetches the data for a specified page.
  ///
  /// - Parameters:
  ///   - isolation: The current isolation context of the page fetch.
  ///   - paging: The ``Paging`` for this operation. You can access the page id to fetch data for
  ///   via the ``Paging/pageId`` property.
  ///   - context: The ``OperationContext`` passed to this operation.
  ///   - continuation: An ``OperationContinuation`` allowing you to yield multiple intermittent
  ///   values from your operation. See <doc:MultistageOperations> for more.
  /// - Returns: The page value for the page.
  func fetchPage(
    isolation: isolated (any Actor)?,
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext,
    with continuation: OperationContinuation<PageValue, PageFailure>
  ) async throws(PageFailure) -> PageValue
}

extension PaginatedRequest {
  public func pageId(
    before page: Page<PageID, PageValue>,
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext
  ) -> PageID? {
    nil
  }

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<
      PaginatedOperationValue<PageID, PageValue>,
      PageFailure
    >
  ) async throws(PageFailure) -> PaginatedOperationValue<PageID, PageValue> {
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
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext,
    with continuation: OperationContinuation<Value, PageFailure>
  ) async throws(PageFailure) -> PaginatedOperationValue<PageID, PageValue> {
    var newPages = context.infiniteValues?.currentPagesTracker?.pages(for: self) ?? []
    for _ in 0..<paging.pages.count {
      let pageId =
        if let lastPage = newPages.last {
          self.pageId(
            after: lastPage,
            using: Paging(pageId: lastPage.id, pages: newPages, request: .allPages),
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
        using: Paging(pageId: pageId, pages: newPages, request: .allPages),
        in: context,
        with: OperationContinuation { [newPages] result, yieldedContext in
          continuation.yield(
            with: result.map {
              var pages = newPages
              pages.append(Page(id: pageId, value: $0))
              return PaginatedOperationValue(runValue: .allPages(pages))
            },
            using: yieldedContext
          )
        }
      )
      newPages.append(Page(id: pageId, value: pageValue))
      context.infiniteValues?.currentPagesTracker?.savePages(newPages)
    }
    return self.allPagesValue(pages: newPages, paging: paging, in: context)
  }

  private func allPagesValue(
    pages: Pages<PageID, PageValue>,
    paging: Paging<PageID, PageValue>,
    in context: OperationContext
  ) -> Value {
    PaginatedOperationValue(
      runValue: .allPages(pages),
      nextPageId: pages.last.map {
        .computed(self.pageId(after: $0, using: paging, in: context))
      } ?? .computed(nil),
      previousPageId: pages.first.map {
        .computed(self.pageId(before: $0, using: paging, in: context))
      } ?? .computed(nil)
    )
  }

  private func fetchInitialPage(
    isolation: isolated (any Actor)?,
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext,
    with continuation: OperationContinuation<Value, PageFailure>
  ) async throws(PageFailure) -> PaginatedOperationValue<PageID, PageValue> {
    let pageValue = try await self.fetchPageWithPublishedEvents(
      isolation: isolation,
      using: paging,
      in: context,
      with: OperationContinuation { result, yieldedContext in
        continuation.yield(
          with: result.map {
            let page = Page(id: paging.pageId, value: $0)
            return PaginatedOperationValue(runValue: .initialPage(page))
          },
          using: yieldedContext
        )
      }
    )
    return self.initialPageValue(pageValue: pageValue, using: paging, in: context)
  }

  private func initialPageValue(
    pageValue: PageValue,
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext
  ) -> Value {
    let page = Page(id: paging.pageId, value: pageValue)
    return PaginatedOperationValue(
      runValue: .initialPage(page),
      nextPageId: .computed(self.pageId(after: page, using: paging, in: context)),
      previousPageId: .computed(self.pageId(before: page, using: paging, in: context))
    )
  }

  private func fetchNextPage(
    isolation: isolated (any Actor)?,
    with pageId: PageID,
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext,
    with continuation: OperationContinuation<Value, PageFailure>
  ) async throws(PageFailure) -> PaginatedOperationValue<PageID, PageValue> {
    let pageValue = try await self.fetchPageWithPublishedEvents(
      isolation: isolation,
      using: Paging(pageId: pageId, pages: paging.pages, request: paging.request),
      in: context,
      with: OperationContinuation { result, yieldedContext in
        continuation.yield(
          with: result.map {
            let next = PaginatedOperationValue.RunValue.NextPage(
              page: Page(id: pageId, value: $0),
              lastPageId: paging.pages.last!.id
            )
            return PaginatedOperationValue(runValue: .nextPage(next))
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
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext
  ) -> Value {
    let page = Page(id: pageId, value: pageValue)
    return PaginatedOperationValue(
      runValue: .nextPage(
        PaginatedOperationValue.RunValue.NextPage(
          page: page,
          lastPageId: paging.pages.last!.id
        )
      ),
      nextPageId: .computed(self.pageId(after: page, using: paging, in: context)),
      previousPageId: paging.pages.first.map {
        .computed(self.pageId(before: $0, using: paging, in: context))
      } ?? .computed(nil)
    )
  }

  private func fetchPreviousPage(
    isolation: isolated (any Actor)?,
    with pageId: PageID,
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext,
    with continuation: OperationContinuation<Value, PageFailure>
  ) async throws(PageFailure) -> PaginatedOperationValue<PageID, PageValue> {
    let pageValue = try await self.fetchPageWithPublishedEvents(
      isolation: isolation,
      using: Paging(pageId: pageId, pages: paging.pages, request: paging.request),
      in: context,
      with: OperationContinuation { result, yieldedContext in
        continuation.yield(
          with: result.map {
            let next = PaginatedOperationValue.RunValue.PreviousPage(
              page: Page(id: pageId, value: $0),
              firstPageId: paging.pages.first!.id
            )
            return PaginatedOperationValue(runValue: .previousPage(next))
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
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext
  ) -> Value {
    let page = Page(id: pageId, value: pageValue)
    return PaginatedOperationValue(
      runValue: .previousPage(
        PaginatedOperationValue.RunValue.PreviousPage(
          page: page,
          firstPageId: paging.pages.first!.id
        )
      ),
      nextPageId: paging.pages.last.map {
        .computed(self.pageId(after: $0, using: paging, in: context))
      } ?? .computed(nil),
      previousPageId: .computed(self.pageId(before: page, using: paging, in: context))
    )
  }

  private func fetchPageWithPublishedEvents(
    isolation: isolated (any Actor)?,
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext,
    with continuation: OperationContinuation<PageValue, PageFailure>
  ) async throws(PageFailure) -> PageValue {
    let id = AnyHashableSendable(paging.pageId)
    context.infiniteValues?.requestSubscriptions.forEach { $0.onPageFetchingStarted(id, context) }
    let continuation = OperationContinuation<PageValue, PageFailure> { result, yieldedContext in
      var context = yieldedContext ?? context
      context.operationResultUpdateReason = .yieldedResult
      context.infiniteValues?.requestSubscriptions
        .forEach { sub in
          let result = result.map {
            Page(id: paging.pageId, value: $0) as any Sendable
          }
          sub.onPageResultReceived(id, result.mapError { $0 }, context)
        }
      continuation.yield(with: result)
    }
    // NB: Can't use Result init helper due to Sendable shenanigans.
    var result: Result<PageValue, PageFailure>
    do {
      let pageValue = try await self.fetchPage(
        isolation: isolation,
        using: paging,
        in: context,
        with: continuation
      )
      result = .success(pageValue)
    } catch {
      result = .failure(error)
    }

    context.infiniteValues?.requestSubscriptions
      .forEach { sub in
        let result = result.map { Page(id: paging.pageId, value: $0) as any Sendable }

        var resultContext = context
        resultContext.operationResultUpdateReason = .returnedFinalResult
        sub.onPageResultReceived(id, result.mapError { $0 }, resultContext)

        sub.onPageFetchingFinished(id, context)
      }
    return try result.get()
  }
}
