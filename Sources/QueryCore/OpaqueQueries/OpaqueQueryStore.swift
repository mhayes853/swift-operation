import Foundation

// MARK: - QueryStore

/// A fully type-erased ``QueryStore``.
///
/// You generally only interact with instances of this type through a ``QueryClient``. See
/// <doc:PatternMatchingAndStateManagement> for more.
@dynamicMemberLookup
public final class OpaqueQueryStore: Sendable {
  private let _base: any OpaqueableQueryStore

  /// Creates an opaque store by type erasing a ``QueryStore``.
  ///
  /// - Parameter base: The store to type-erase.
  public init(erasing base: QueryStore<some QueryStateProtocol>) {
    self._base = base
  }
}

// MARK: - Base

extension OpaqueQueryStore {
  /// The base ``QueryStore``.
  public var base: any Sendable {
    self._base
  }
}

// MARK: - Path

extension OpaqueQueryStore: QueryPathable {
  /// The ``QueryPath`` of the query managed by this store.
  public var path: QueryPath {
    self._base.path
  }
}

// MARK: - Context

extension OpaqueQueryStore {
  /// The ``QueryContext`` that is passed to the query every time ``fetch(using:handler:)`` is
  /// called.
  public var context: QueryContext {
    get { self._base.context }
    set { self._base.context = newValue }
  }
}

// MARK: - Automatic Fetching

extension OpaqueQueryStore {
  /// Whether or not automatic fetching is enabled for this query.
  ///
  /// Automatic fetching is defined as the process of data being fetched from this query without
  /// explicitly calling ``fetch(using:handler:)``. This includes, but not limited to:
  /// 1. Automatically fetching from this query when subscribed to via ``subscribe(with:)``.
  /// 2. Automatically fetching from this query when the app re-enters from the background.
  /// 3. Automatically fetching from this query when the user's network connection comes back online.
  /// 4. Automatically fetching from this query via a ``QueryController``.
  /// 5. Automatically fetching from this query via ``QueryRequest/refetchOnChange(of:)``.
  ///
  /// When automatic fetching is disabled, you are responsible for manually calling
  /// ``fetch(using:handler:)`` to ensure that your query always has the latest data.
  ///
  /// When you use the default initializer of a ``QueryClient``, automatic fetching is enabled for all
  /// ``QueryRequest`` conformances, and disabled for all ``MutationRequest`` conformances.
  ///
  /// Queries can individually enable or disable automatic fetching through the
  /// ``QueryRequest/enableAutomaticFetching(onlyWhen:)`` modifier.
  public var isAutomaticFetchingEnabled: Bool {
    self._base.isAutomaticFetchingEnabled
  }
}

// MARK: - State

extension OpaqueQueryStore {
  /// The current state of this query.
  public var state: OpaqueQueryState {
    self._base.opaqueState
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<OpaqueQueryState, NewValue>
  ) -> NewValue {
    self.state[keyPath: keyPath]
  }

  /// Exclusively accesses this store inside the specified closure.
  ///
  /// The store is thread-safe, but accessing individual properties without exclusive access can
  /// still lead to high-level data races. Use this method to ensure that your code has exclusive
  /// access to the store when performing multiple property accesses to compute a value or modify
  /// the store.
  ///
  /// ```swift
  /// let store: OpaqueQueryStore
  ///
  /// // 🔴 Is prone to high-level data races.
  /// store.currentValue = (store.currentValue as! Int) + 1
  ///
  /// // ✅ No data races.
  /// store.withExclusiveAccess {
  ///   store.currentValue = (store.currentValue as! Int) + 1
  /// }
  /// ```
  ///
  /// - Parameter fn: A closure with exclusive access to the store.
  /// - Returns: Whatever `fn` returns.
  public func withExclusiveAccess<T>(_ fn: () throws -> sending T) rethrows -> sending T {
    try self._base.withExclusiveAccess(fn)
  }
}

// MARK: - Current Value

extension OpaqueQueryStore {
  /// The current value of the query.
  public var currentValue: (any Sendable)? {
    get { self.state.currentValue }
    @available(*, unavailable, message: "Call `uncheckedSetCurrentValue` instead.")
    set { self.uncheckedSetCurrentValue(newValue) }
  }

  /// Sets the ``currentValue`` of the query.
  ///
  /// This method will attempt force cast `value` to the underlying data type that represents the
  /// value stored in your query. As such, prefer conditionally casting ``base`` to a strongly
  /// typed ``QueryStore``, and setting the value through ``QueryStore/currentValue`` instead.
  ///
  /// - Parameters:
  ///   - value: The new query value.
  ///   - context: The ``QueryContext`` to set the value in
  public func uncheckedSetCurrentValue(
    _ value: (any Sendable)?,
    using context: QueryContext? = nil
  ) {
    self.uncheckedSetResult(to: .success(value), using: context)
  }
}

// MARK: - Set Result

extension OpaqueQueryStore {
  /// Sets the result of the query.
  ///
  /// This method will attempt force cast successful `result`s to the underlying data type that
  /// represents the value stored in your query. As such, prefer conditionally casting ``base`` to
  /// a strongly typed ``QueryStore``, and setting the value through ``QueryStore/currentValue``
  /// instead.
  ///
  /// - Parameters:
  ///   - result: The `Result`.
  ///   - context: The ``QueryContext`` to set the result in
  public func uncheckedSetResult(
    to result: Result<(any Sendable)?, any Error>,
    using context: QueryContext? = nil
  ) {
    self._base.opaqueSetResult(to: result, using: context)
  }
}

// MARK: - Reset

extension OpaqueQueryStore {
  /// Resets the state of the query to its original values.
  ///
  /// > Important: This will cancel all active ``QueryTask``s on the query. Those cancellations will not be
  /// > reflected in the reset query state.
  ///
  /// - Parameter context: The ``QueryContext`` to reset the query in.
  public func resetState(using context: QueryContext? = nil) {
    self._base.resetState(using: context)
  }
}

// MARK: - Is Stale

extension OpaqueQueryStore {
  /// Whether or not the currently fetched data from the query is considered stale.
  ///
  /// When this value is true, you should generally try to refetch the query data as soon as
  /// possible. ``subscribe(with:)`` will use this property to decide whether or not to
  /// automatically fetch the query's data when the first active subscription is made to this store.
  ///
  /// A query can customize the value of this property via the
  /// ``QueryRequest/staleWhen(predicate:)`` modifier.
  public var isStale: Bool {
    self._base.isStale
  }
}

// MARK: - Fetch

extension OpaqueQueryStore {
  /// Fetches the query's data.
  ///
  /// - Parameters:
  ///   - context: The ``QueryContext`` to use for the underlying ``QueryTask``.
  ///   - handler: An ``OpaqueQueryEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched data.
  @discardableResult
  public func fetch(
    using context: QueryContext? = nil,
    handler: OpaqueQueryEventHandler = OpaqueQueryEventHandler()
  ) async throws -> any Sendable {
    try await self._base.opaqueFetch(using: context, handler: handler)
  }

  /// Creates a ``QueryTask`` to fetch the query's data.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``QueryTask/runIfNeeded()`` to fetch the data.
  ///
  /// - Parameter context: The ``QueryContext`` for the task.
  /// - Returns: A task to fetch the query's data.
  @discardableResult
  public func fetchTask(using context: QueryContext? = nil) -> QueryTask<any Sendable> {
    self._base.opaqueFetchTask(using: context)
  }
}

// MARK: - Subscribe

extension OpaqueQueryStore {
  /// The total number of subscribers on this store.
  public var subscriberCount: Int {
    self._base.subscriberCount
  }

  /// Subscribes to events from this store using an ``OpaqueQueryEventHandler``.
  ///
  /// If the subscription is the first active subscription on this store, this method will begin
  /// fetching the query's data if both ``isStale`` and ``isAutomaticFetchingEnabled`` are true. If
  /// the subscriber count drops to 0 whilst performing this data fetch, then the fetch is
  /// cancelled and a `CancellationError` will be present on the ``state`` property.
  ///
  /// - Parameter handler: The event handler.
  /// - Returns: A ``QuerySubscription``.
  public func subscribe(with handler: OpaqueQueryEventHandler) -> QuerySubscription {
    self._base.opaqueSubscribe(with: handler)
  }
}

// MARK: - OpaquableQueryStore

private protocol OpaqueableQueryStore: Sendable {
  var opaqueState: OpaqueQueryState { get }
  var isAutomaticFetchingEnabled: Bool { get }
  var path: QueryPath { get }
  var context: QueryContext { get nonmutating set }
  var subscriberCount: Int { get }
  var isStale: Bool { get }
  func withExclusiveAccess<T>(_ fn: () throws -> sending T) rethrows -> sending T

  func opaqueSetResult(to result: Result<(any Sendable)?, any Error>, using context: QueryContext?)
  func opaqueFetch(
    using context: QueryContext?,
    handler: OpaqueQueryEventHandler
  ) async throws -> any Sendable
  func resetState(using context: QueryContext?)
  func opaqueFetchTask(using context: QueryContext?) -> QueryTask<any Sendable>
  func opaqueSubscribe(with handler: OpaqueQueryEventHandler) -> QuerySubscription
}

extension QueryStore: OpaqueableQueryStore {
  var opaqueState: OpaqueQueryState { OpaqueQueryState(self.state) }

  func opaqueSetResult(
    to result: Result<(any Sendable)?, any Error>,
    using context: QueryContext?
  ) {
    self.setResult(to: result.map { $0 as! State.StateValue }, using: context)
  }

  func opaqueFetch(
    using context: QueryContext?,
    handler: OpaqueQueryEventHandler
  ) async throws -> any Sendable {
    try await self.fetch(using: context, handler: handler.casted(to: State.self))
  }

  func opaqueFetchTask(using context: QueryContext?) -> QueryTask<any Sendable> {
    self.fetchTask(using: context).map { $0 }
  }

  func opaqueSubscribe(with handler: OpaqueQueryEventHandler) -> QuerySubscription {
    self.subscribe(with: handler.casted(to: State.self))
  }
}
