import Foundation
import IdentifiedCollections

// MARK: - Detached

extension QueryStore {
  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``QueryClient``. As such, accessing the
  /// ``QueryContext/queryClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - query: The ``InfiniteQueryRequest``.
  ///   - initialValue: The initial value.
  ///   - initialContext: The default ``QueryContext``.
  /// - Returns: A store.
  public static func detached<Query: InfiniteQueryRequest<State.PageID, State.PageValue>>(
    query: Query,
    initialValue: Query.State.StateValue = [],
    initialContext: QueryContext = QueryContext()
  ) -> QueryStore<State> where State == InfiniteQueryState<State.PageID, State.PageValue> {
    .detached(
      query: query,
      initialState: InfiniteQueryState(
        initialValue: initialValue,
        initialPageId: query.initialPageId
      ),
      initialContext: initialContext
    )
  }

  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``QueryClient``. As such, accessing the
  /// ``QueryContext/queryClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - query: The ``InfiniteQueryRequest``.
  ///   - initialContext: The default ``QueryContext``.
  /// - Returns: A store.
  public static func detached<Query: InfiniteQueryRequest<State.PageID, State.PageValue>>(
    query: DefaultInfiniteQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStore<State> where State == InfiniteQueryState<State.PageID, State.PageValue> {
    .detached(query: query, initialValue: query.defaultValue, initialContext: initialContext)
  }
}

// MARK: - Fetch All Pages

extension QueryStore where State: _InfiniteQueryStateProtocol {
  /// Refetches all existing pages on the query.
  ///
  /// This method will refetch pages in a waterfall effect, starting from the first page, and then
  /// continuing until either the last page is fetched, or until no more pages can be fetched.
  ///
  /// If no pages have been fetched previously, then no pages will be fetched.
  ///
  /// - Parameters:
  ///   - configuration: The ``QueryTaskConfiguration`` to use for the underlying ``QueryTask``.
  ///   - handler: An ``InfiniteQueryEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched data.
  @discardableResult
  public func fetchAllPages(
    using configuration: QueryTaskConfiguration? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPages<State.PageID, State.PageValue> {
    let value = try await self.fetch(
      using: self.fetchAllPagesTaskConfiguration(using: configuration),
      handler: handler
    )
    return self.allPages(from: value)
  }

  /// Creates a ``QueryTask`` that refetches all existing pages on the query.
  ///
  /// The task will refetch pages in a waterfall effect, starting from the first page, and then
  /// continuing until either the last page is fetched, or until no more pages can be fetched.
  ///
  /// If no pages have been fetched previously, then no pages will be fetched.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``QueryTask/runIfNeeded()`` to fetch the data.
  ///
  /// - Parameters:
  ///   - configuration: The ``QueryTaskConfiguration`` to use for the underlying ``QueryTask``.
  ///   - handler: An ``InfiniteQueryEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: A task to refetch all pages.
  public func fetchAllPagesTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPages<State.PageID, State.PageValue>> {
    self.fetchTask(using: self.fetchAllPagesTaskConfiguration(using: configuration))
      .map(self.allPages(from:))
  }

  private func allPages(
    from value: InfiniteQueryValue<State.PageID, State.PageValue>
  ) -> InfiniteQueryPages<State.PageID, State.PageValue> {
    switch value.response {
    case let .allPages(pages): pages
    default: self.state.currentValue
    }
  }

  private func fetchAllPagesTaskConfiguration(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTaskConfiguration {
    var configuration = configuration ?? QueryTaskConfiguration(context: self.context)
    configuration.context.infiniteValues.fetchType = .allPages
    configuration.name = self.fetchAllPagesTaskName
    return configuration
  }

  private var fetchAllPagesTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Fetch All Pages Task"
  }
}

// MARK: - Fetch Next Page

extension QueryStore where State: _InfiniteQueryStateProtocol {
  /// Fetches the page that will be placed after the last page in ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// This method can fetch data in parallel with ``fetchPreviousPage(using:handler:)``.
  ///
  /// - Parameters:
  ///   - configuration: The ``QueryTaskConfiguration`` to use for the underlying ``QueryTask``.
  ///   - handler: An ``InfiniteQueryEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched page.
  @discardableResult
  public func fetchNextPage(
    using configuration: QueryTaskConfiguration? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    guard self.hasNextPage else { return nil }
    let value = try await self.fetch(
      using: self.fetchNextPageTaskConfiguration(using: configuration),
      handler: handler
    )
    return self.nextPage(from: value)
  }

  /// Creates a ``QueryTask`` to fetch the page that will be placed after the last page in
  /// ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// The task can fetch data in parallel with ``fetchPreviousPage(using:handler:)``.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``QueryTask/runIfNeeded()`` to fetch the data.
  ///
  /// - Parameters:
  ///   - configuration: The ``QueryTaskConfiguration`` to use for the underlying ``QueryTask``.
  ///   - handler: An ``InfiniteQueryEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched page.
  public func fetchNextPageTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPage<State.PageID, State.PageValue>?> {
    guard self.hasNextPage else {
      return QueryTask(
        configuration: self.fetchNextPageTaskConfiguration(using: configuration)
      ) { _ in nil }
    }
    return self.fetchTask(using: self.fetchNextPageTaskConfiguration(using: configuration))
      .map(self.nextPage(from:))
  }

  private func nextPage(
    from value: InfiniteQueryValue<State.PageID, State.PageValue>
  ) -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    switch value.response {
    case let .nextPage(next): next?.page
    case let .initialPage(page): page
    default: nil
    }
  }

  private func fetchNextPageTaskConfiguration(
    using configuration: QueryTaskConfiguration?
  ) -> QueryTaskConfiguration {
    var configuration = configuration ?? QueryTaskConfiguration(context: self.context)
    configuration.context.infiniteValues.fetchType = .nextPage
    configuration.name = configuration.name ?? self.fetchNextPageTaskName
    return configuration
  }

  private var fetchNextPageTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Fetch Next Page Task"
  }
}

// MARK: - Fetch Previous Page

extension QueryStore where State: _InfiniteQueryStateProtocol {
  /// Fetches the page that will be placed before the first page in ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// This method can fetch data in parallel with ``fetchNextPage(using:handler:)``.
  ///
  /// - Parameters:
  ///   - configuration: The ``QueryTaskConfiguration`` to use for the underlying ``QueryTask``.
  ///   - handler: An ``InfiniteQueryEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched page.
  @discardableResult
  public func fetchPreviousPage(
    using configuration: QueryTaskConfiguration? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    guard self.hasPreviousPage else { return nil }
    let value = try await self.fetch(
      using: self.fetchPreviousPageTaskConfiguration(using: configuration),
      handler: handler
    )
    return self.previousPage(from: value)
  }

  /// Creates a ``QueryTask`` to fetch the page that will be placed before the first page in
  /// ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// The task can fetch data in parallel with ``fetchNextPage(using:handler:)``.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``QueryTask/runIfNeeded()`` to fetch the data.
  ///
  /// - Parameters:
  ///   - configuration: The ``QueryTaskConfiguration`` to use for the underlying ``QueryTask``.
  ///   - handler: An ``InfiniteQueryEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched page.
  public func fetchPreviousPageTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPage<State.PageID, State.PageValue>?> {
    guard self.hasPreviousPage else {
      return QueryTask(
        configuration: self.fetchPreviousPageTaskConfiguration(using: configuration)
      ) { _ in nil }
    }
    return self.fetchTask(using: self.fetchPreviousPageTaskConfiguration(using: configuration))
      .map(self.previousPage(from:))
  }

  private func previousPage(
    from value: InfiniteQueryValue<State.PageID, State.PageValue>
  ) -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    switch value.response {
    case let .previousPage(previous): previous?.page
    case let .initialPage(page): page
    default: nil
    }
  }

  private func fetchPreviousPageTaskConfiguration(
    using configuration: QueryTaskConfiguration?
  ) -> QueryTaskConfiguration {
    var configuration = configuration ?? QueryTaskConfiguration(context: self.context)
    configuration.context.infiniteValues.fetchType = .previousPage
    configuration.name = configuration.name ?? self.fetchPreviousPageTaskName
    return configuration
  }

  private var fetchPreviousPageTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Fetch Previous Page Task"
  }
}

// MARK: - Fetch

extension QueryStore where State: _InfiniteQueryStateProtocol {
  private func fetch(
    using configuration: QueryTaskConfiguration,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue>
  ) async throws -> InfiniteQueryValue<State.PageID, State.PageValue> {
    let subscription = configuration.context.infiniteValues.addRequestSubscriber(
      from: handler,
      isTemporary: true
    )
    defer { subscription.cancel() }
    return try await self.fetch(
      using: configuration,
      handler: self.queryStoreHandler(for: handler)
    )
  }
}

// MARK: - Subscribe

extension QueryStore where State: _InfiniteQueryStateProtocol {
  /// Subscribes to events from this store using a ``InfiniteQueryEventHandler``.
  ///
  /// If the subscription is the first active subscription on this store, this method will begin
  /// fetching the query's data if both ``isStale`` and ``isAutomaticFetchingEnabled`` are true. If
  /// the subscriber count drops to 0 whilst performing this data fetch, then the fetch is
  /// cancelled and a `CancellationError` will be present on the ``state`` property.
  ///
  /// - Parameter handler: The event handler.
  public func subscribe(
    with handler: InfiniteQueryEventHandler<State.PageID, State.PageValue>
  ) -> QuerySubscription {
    let contextSubscription = context.infiniteValues.addRequestSubscriber(
      from: handler,
      isTemporary: false
    )
    let baseSubscription = self.subscribe(with: self.queryStoreHandler(for: handler))
    return QuerySubscription {
      baseSubscription.cancel()
      contextSubscription.cancel()
    }
  }
}

// MARK: - InfiniteQueryEventHandler

extension QueryStore where State: _InfiniteQueryStateProtocol {
  private func queryStoreHandler(
    for handler: InfiniteQueryEventHandler<State.PageID, State.PageValue>
  ) -> QueryEventHandler<State> {
    QueryEventHandler(
      onStateChanged: {
        handler.onStateChanged?($0 as! InfiniteQueryState<State.PageID, State.PageValue>, $1)
      },
      onFetchingStarted: handler.onFetchingStarted,
      onFetchingEnded: handler.onFetchingEnded,
      onResultReceived: { result, context in
        guard context.queryResultUpdateReason == .returnedFinalResult else { return }
        handler.onResultReceived?(result.map { [weak self] _ in self?.currentValue ?? [] }, context)
      }
    )
  }
}
