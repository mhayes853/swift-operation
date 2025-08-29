import Foundation
import IdentifiedCollections

// MARK: - Detached

extension OperationStore {
  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``OperationClient``. As such, accessing the
  /// ``OperationContext/OperationClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - query: The ``InfiniteQueryRequest``.
  ///   - initialValue: The initial value.
  ///   - initialContext: The default ``OperationContext``.
  /// - Returns: A store.
  public static func detached<Query: InfiniteQueryRequest>(
    query: Query,
    initialValue: Query.State.StateValue = [],
    initialContext: OperationContext = OperationContext()
  ) -> OperationStore<State> where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
    .detached(
      operation: query,
      initialState: InfiniteQueryState(
        initialValue: initialValue,
        initialPageId: query.initialPageId
      ),
      initialContext: initialContext
    )
  }

  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``OperationClient``. As such, accessing the
  /// ``OperationContext/OperationClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - query: The ``InfiniteQueryRequest``.
  ///   - initialContext: The default ``OperationContext``.
  /// - Returns: A store.
  public static func detached<Query: InfiniteQueryRequest>(
    query: Query.Default,
    initialContext: OperationContext = OperationContext()
  ) -> OperationStore<Query.Default.State> where State == DefaultOperation<Query>.State {
    .detached(
      operation: query,
      initialState: query.initialState,
      initialContext: initialContext
    )
  }
}

// MARK: - Fetch All Pages

extension OperationStore where State: _InfiniteQueryStateProtocol {
  /// Refetches all existing pages on the query.
  ///
  /// This method will refetch pages in a waterfall effect, starting from the first page, and then
  /// continuing until either the last page is fetched, or until no more pages can be fetched.
  ///
  /// If no pages have been fetched previously, then no pages will be fetched.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` to use for the underlying ``OperationTask``.
  ///   - handler: An ``InfiniteQueryEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched data.
  @discardableResult
  public func refetchAllPages(
    using context: OperationContext? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPages<State.PageID, State.PageValue> {
    let value = try await self.fetch(
      using: self.fetchAllPagesTaskConfiguration(using: context),
      handler: handler
    )
    return self.allPages(from: value)
  }

  /// Creates a ``OperationTask`` that refetches all existing pages on the query.
  ///
  /// The task will refetch pages in a waterfall effect, starting from the first page, and then
  /// continuing until either the last page is fetched, or until no more pages can be fetched.
  ///
  /// If no pages have been fetched previously, then no pages will be fetched.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``OperationTask/runIfNeeded()`` to fetch the data.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` to use for the underlying ``OperationTask``.
  /// - Returns: A task to refetch all pages.
  public func refetchAllPagesTask(
    using context: OperationContext? = nil
  ) -> OperationTask<InfiniteQueryPages<State.PageID, State.PageValue>, any Error> {
    self.runTask(using: self.fetchAllPagesTaskConfiguration(using: context))
      .map(self.allPages(from:))
  }

  private func allPages(
    from value: InfiniteQueryOperationValue<State.PageID, State.PageValue>
  ) -> InfiniteQueryPages<State.PageID, State.PageValue> {
    switch value.fetchValue {
    case .allPages(let pages): pages
    default: self.state.currentValue
    }
  }

  private func fetchAllPagesTaskConfiguration(
    using context: OperationContext? = nil
  ) -> OperationContext {
    var context = self.ensuredContext(from: context)
    context.infiniteValues?.fetchType = .allPages
    context.operationTaskConfiguration.name = self.fetchAllPagesTaskName
    return context
  }

  private var fetchAllPagesTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Fetch All Pages Task"
  }
}

// MARK: - Fetch Next Page

extension OperationStore where State: _InfiniteQueryStateProtocol {
  /// Fetches the page that will be placed after the last page in ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// This method can fetch data in parallel with ``fetchPreviousPage(using:handler:)``.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` to use for the underlying ``OperationTask``.
  ///   - handler: An ``InfiniteQueryEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched page.
  @discardableResult
  public func fetchNextPage(
    using context: OperationContext? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    guard self.hasNextPage else { return nil }
    let value = try await self.fetch(
      using: self.fetchNextPageTaskConfiguration(using: context),
      handler: handler
    )
    return self.nextPage(from: value)
  }

  /// Creates a ``OperationTask`` to fetch the page that will be placed after the last page in
  /// ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// The task can fetch data in parallel with ``fetchPreviousPage(using:handler:)``.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``OperationTask/runIfNeeded()`` to fetch the data.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` to use for the underlying ``OperationTask``.
  /// - Returns: The fetched page.
  public func fetchNextPageTask(
    using context: OperationContext? = nil
  ) -> OperationTask<InfiniteQueryPage<State.PageID, State.PageValue>?, any Error> {
    guard self.hasNextPage else {
      return OperationTask(context: self.fetchNextPageTaskConfiguration(using: context)) { _, _ in
        nil
      }
    }
    return self.runTask(using: self.fetchNextPageTaskConfiguration(using: context))
      .map(self.nextPage(from:))
  }

  private func nextPage(
    from value: InfiniteQueryOperationValue<State.PageID, State.PageValue>
  ) -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    switch value.fetchValue {
    case .nextPage(let next): next.page
    case .initialPage(let page): page
    default: nil
    }
  }

  private func fetchNextPageTaskConfiguration(
    using context: OperationContext?
  ) -> OperationContext {
    var context = self.ensuredContext(from: context)
    context.infiniteValues?.fetchType = .nextPage
    context.operationTaskConfiguration.name =
      context.operationTaskConfiguration.name ?? self.fetchNextPageTaskName
    return context
  }

  private var fetchNextPageTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Fetch Next Page Task"
  }
}

// MARK: - Fetch Previous Page

extension OperationStore where State: _InfiniteQueryStateProtocol {
  /// Fetches the page that will be placed before the first page in ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// This method can fetch data in parallel with ``fetchNextPage(using:handler:)``.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` to use for the underlying ``OperationTask``.
  ///   - handler: An ``InfiniteQueryEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched page.
  @discardableResult
  public func fetchPreviousPage(
    using context: OperationContext? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    guard self.hasPreviousPage else { return nil }
    let value = try await self.fetch(
      using: self.fetchPreviousPageTaskConfiguration(using: context),
      handler: handler
    )
    return self.previousPage(from: value)
  }

  /// Creates a ``OperationTask`` to fetch the page that will be placed before the first page in
  /// ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// The task can fetch data in parallel with ``fetchNextPage(using:handler:)``.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``OperationTask/runIfNeeded()`` to fetch the data.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` to use for the underlying ``OperationTask``.
  /// - Returns: The fetched page.
  public func fetchPreviousPageTask(
    using context: OperationContext? = nil
  ) -> OperationTask<InfiniteQueryPage<State.PageID, State.PageValue>?, any Error> {
    guard self.hasPreviousPage else {
      return OperationTask(context: self.fetchPreviousPageTaskConfiguration(using: context)) {
        _,
        _ in
        nil
      }
    }
    return self.runTask(using: self.fetchPreviousPageTaskConfiguration(using: context))
      .map(self.previousPage(from:))
  }

  private func previousPage(
    from value: InfiniteQueryOperationValue<State.PageID, State.PageValue>
  ) -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    switch value.fetchValue {
    case .previousPage(let previous): previous.page
    case .initialPage(let page): page
    default: nil
    }
  }

  private func fetchPreviousPageTaskConfiguration(
    using context: OperationContext?
  ) -> OperationContext {
    var context = self.ensuredContext(from: context)
    context.infiniteValues?.fetchType = .previousPage
    context.operationTaskConfiguration.name =
      context.operationTaskConfiguration.name ?? self.fetchPreviousPageTaskName
    return context
  }

  private var fetchPreviousPageTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Fetch Previous Page Task"
  }
}

// MARK: - Fetch

extension OperationStore where State: _InfiniteQueryStateProtocol {
  private func fetch(
    using context: OperationContext,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue>
  ) async throws -> InfiniteQueryOperationValue<State.PageID, State.PageValue> {
    let subscription = context.infiniteValues?
      .addRequestSubscriber(from: handler, isTemporary: true)
    defer { subscription?.cancel() }
    return try await self.run(using: context, handler: self.operationEventHandler(for: handler))
  }
}

// MARK: - Subscribe

extension OperationStore where State: _InfiniteQueryStateProtocol {
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
  ) -> OperationSubscription {
    let context = self.ensuredContext(from: nil)
    let contextSubscription = context.infiniteValues?
      .addRequestSubscriber(from: handler, isTemporary: false)
    let baseSubscription = self.subscribe(with: self.operationEventHandler(for: handler))
    return .combined([baseSubscription, contextSubscription ?? .empty])
  }
}

// MARK: - InfiniteQueryEventHandler

extension OperationStore where State: _InfiniteQueryStateProtocol {
  private func operationEventHandler(
    for handler: InfiniteQueryEventHandler<State.PageID, State.PageValue>
  ) -> OperationEventHandler<State> {
    OperationEventHandler(
      onStateChanged: {
        handler.onStateChanged?($0 as! InfiniteQueryState<State.PageID, State.PageValue>, $1)
      },
      onFetchingStarted: handler.onFetchingStarted,
      onFetchingEnded: handler.onFetchingEnded,
      onResultReceived: { result, context in
        guard context.operationResultUpdateReason == .returnedFinalResult else { return }
        handler.onResultReceived?(result.map { [weak self] _ in self?.currentValue ?? [] }, context)
      }
    )
  }
}

// MARK: - Context

extension OperationStore where State: _InfiniteQueryStateProtocol {
  private func ensuredContext(from context: OperationContext?) -> OperationContext {
    let values = self.context.ensureInfiniteValues()
    var context = context ?? self.context
    context.infiniteValues?.requestSubscriptions = values.requestSubscriptions
    return context
  }
}
