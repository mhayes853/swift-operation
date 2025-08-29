import Foundation

// MARK: - OperationStore

/// A fully type-erased ``OperationStore``.
///
/// You generally only interact with instances of this type through a ``OperationClient``. See
/// <doc:PatternMatchingAndStateManagement> for more.
@dynamicMemberLookup
public final class OpaqueOperationStore: Sendable {
  private let _base: any OpaqueableOperationStore

  /// Creates an opaque store by type erasing a ``OperationStore``.
  ///
  /// - Parameter base: The store to type-erase.
  public init(erasing base: OperationStore<some OperationState>) {
    self._base = base
  }
}

// MARK: - Base

extension OpaqueOperationStore {
  /// The base ``OperationStore``.
  public var base: any Sendable {
    self._base
  }
}

// MARK: - Path

extension OpaqueOperationStore: OperationPathable {
  /// The ``OperationPath`` of the query managed by this store.
  public var path: OperationPath {
    self._base.path
  }
}

// MARK: - Context

extension OpaqueOperationStore {
  /// The ``OperationContext`` that is passed to the query every time ``fetch(using:handler:)`` is
  /// called.
  public var context: OperationContext {
    get { self._base.context }
    set { self._base.context = newValue }
  }
}

// MARK: - Automatic Fetching

extension OpaqueOperationStore {
  /// Whether or not automatic fetching is enabled for this query.
  ///
  /// Automatic fetching is defined as the process of data being fetched from this query without
  /// explicitly calling ``fetch(using:handler:)``. This includes, but not limited to:
  /// 1. Automatically fetching from this query when subscribed to via ``subscribe(with:)``.
  /// 2. Automatically fetching from this query when the app re-enters from the background.
  /// 3. Automatically fetching from this query when the user's network connection comes back online.
  /// 4. Automatically fetching from this query via a ``OperationController``.
  /// 5. Automatically fetching from this query via ``QueryRequest/refetchOnChange(of:)``.
  ///
  /// When automatic fetching is disabled, you are responsible for manually calling
  /// ``fetch(using:handler:)`` to ensure that your query always has the latest data.
  ///
  /// When you use the default initializer of a ``OperationClient``, automatic fetching is enabled for all
  /// ``QueryRequest`` conformances, and disabled for all ``MutationRequest`` conformances.
  ///
  /// Queries can individually enable or disable automatic fetching through the
  /// ``QueryRequest/enableAutomaticFetching(onlyWhen:)`` modifier.
  public var isAutomaticFetchingEnabled: Bool {
    self._base.isAutomaticFetchingEnabled
  }
}

// MARK: - State

extension OpaqueOperationStore {
  /// The current state of this query.
  public var state: OpaqueOperationState {
    self._base.opaqueState
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<OpaqueOperationState, NewValue>
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
  /// let store: OpaqueOperationStore
  ///
  /// // 🔴 Is prone to high-level data races.
  /// store.currentValue = (store.currentValue as! Int) + 1
  ///
  /// // ✅ No data races.
  /// store.withExclusiveAccess {
  ///   $0.currentValue = ($0.currentValue as! Int) + 1
  /// }
  /// ```
  ///
  /// - Parameter fn: A closure with exclusive access to the store.
  /// - Returns: Whatever `fn` returns.
  public func withExclusiveAccess<T>(
    _ fn: (OpaqueOperationStore) throws -> sending T
  ) rethrows -> sending T {
    try self._base.opaqueWithExclusiveAccess { try fn(self) }
  }
}

// MARK: - Current Value

extension OpaqueOperationStore {
  /// The current value of the query.
  public var currentValue: any Sendable {
    get { self.state.currentValue }
    @available(*, unavailable, message: "Call `uncheckedSetCurrentValue` instead.")
    set { self.uncheckedSetCurrentValue(newValue) }
  }

  /// Sets the ``currentValue`` of the query.
  ///
  /// This method will attempt force cast `value` to the underlying data type that represents the
  /// value stored in your query. As such, prefer conditionally casting ``base`` to a strongly
  /// typed ``OperationStore``, and setting the value through ``OperationStore/currentValue`` instead.
  ///
  /// - Parameters:
  ///   - value: The new query value.
  ///   - context: The ``OperationContext`` to set the value in
  public func uncheckedSetCurrentValue(
    _ value: any Sendable,
    using context: OperationContext? = nil
  ) {
    self.uncheckedSetResult(to: .success(value), using: context)
  }
}

// MARK: - Set Result

extension OpaqueOperationStore {
  /// Sets the result of the query.
  ///
  /// This method will attempt force cast successful `result`s to the underlying data type that
  /// represents the value stored in your query. As such, prefer conditionally casting ``base`` to
  /// a strongly typed ``OperationStore``, and setting the value through ``OperationStore/currentValue``
  /// instead.
  ///
  /// - Parameters:
  ///   - result: The `Result`.
  ///   - context: The ``OperationContext`` to set the result in
  public func uncheckedSetResult(
    to result: Result<any Sendable, any Error>,
    using context: OperationContext? = nil
  ) {
    self._base.opaqueSetResult(to: result, using: context)
  }
}

// MARK: - Reset

extension OpaqueOperationStore {
  /// Resets the state of the query to its original values.
  ///
  /// > Important: This will cancel all active ``OperationTask``s on the query. Those cancellations will not be
  /// > reflected in the reset query state.
  ///
  /// - Parameter context: The ``OperationContext`` to reset the query in.
  public func resetState(using context: OperationContext? = nil) {
    self._base.resetState(using: context)
  }
}

// MARK: - Is Stale

extension OpaqueOperationStore {
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

extension OpaqueOperationStore {
  /// Runs the operation.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` to use for the underlying ``OperationTask``.
  ///   - handler: An ``OpaqueOperationEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The operation's returned data.
  @discardableResult
  public func run(
    using context: OperationContext? = nil,
    handler: OpaqueOperationEventHandler = OpaqueOperationEventHandler()
  ) async throws -> any Sendable {
    try await self._base.opaqueRun(using: context, handler: handler)
  }

  /// Creates a ``OperationTask`` to run the operation.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``OperationTask/runIfNeeded()`` to fetch the data.
  ///
  /// - Parameter context: The ``OperationContext`` for the task.
  /// - Returns: A task to run the operation.
  @discardableResult
  public func runTask(using context: OperationContext? = nil) -> OperationTask<
    any Sendable, any Error
  > {
    self._base.opaqueRunTask(using: context)
  }
}

// MARK: - Subscribe

extension OpaqueOperationStore {
  /// The total number of subscribers on this store.
  public var subscriberCount: Int {
    self._base.subscriberCount
  }

  /// Subscribes to events from this store using an ``OpaqueOperationEventHandler``.
  ///
  /// If the subscription is the first active subscription on this store, this method will begin
  /// fetching the query's data if both ``isStale`` and ``isAutomaticFetchingEnabled`` are true. If
  /// the subscriber count drops to 0 whilst performing this data fetch, then the fetch is
  /// cancelled and a `CancellationError` will be present on the ``state`` property.
  ///
  /// - Parameter handler: The event handler.
  /// - Returns: A ``OperationSubscription``.
  public func subscribe(with handler: OpaqueOperationEventHandler) -> OperationSubscription {
    self._base.opaqueSubscribe(with: handler)
  }
}

// MARK: - OpaquableOperationStore

private protocol OpaqueableOperationStore: Sendable {
  var opaqueState: OpaqueOperationState { get }
  var isAutomaticFetchingEnabled: Bool { get }
  var path: OperationPath { get }
  var context: OperationContext { get nonmutating set }
  var subscriberCount: Int { get }
  var isStale: Bool { get }
  func opaqueWithExclusiveAccess<T>(_ fn: () throws -> sending T) rethrows -> sending T

  func opaqueSetResult(
    to result: Result<any Sendable, any Error>,
    using context: OperationContext?
  )
  func opaqueRun(
    using context: OperationContext?,
    handler: OpaqueOperationEventHandler
  ) async throws -> any Sendable
  func resetState(using context: OperationContext?)
  func opaqueRunTask(using context: OperationContext?) -> OperationTask<any Sendable, any Error>
  func opaqueSubscribe(with handler: OpaqueOperationEventHandler) -> OperationSubscription
}

extension OperationStore: OpaqueableOperationStore {
  var opaqueState: OpaqueOperationState { OpaqueOperationState(self.state) }

  func opaqueSetResult(
    to result: Result<any Sendable, any Error>,
    using context: OperationContext?
  ) {
    self.setResult(
      to: result.map { $0 as! State.StateValue }.mapError { $0 as! State.Failure },
      using: context
    )
  }

  func opaqueRun(
    using context: OperationContext?,
    handler: OpaqueOperationEventHandler
  ) async throws -> any Sendable {
    try await self.run(using: context, handler: handler.casted(to: State.self))
  }

  func opaqueRunTask(using context: OperationContext?) -> OperationTask<any Sendable, any Error> {
    self.runTask(using: context).map { $0 }.mapError { $0 }
  }

  func opaqueSubscribe(with handler: OpaqueOperationEventHandler) -> OperationSubscription {
    self.subscribe(with: handler.casted(to: State.self))
  }

  func opaqueWithExclusiveAccess<T>(_ fn: () throws -> sending T) rethrows -> sending T {
    try self.withExclusiveAccess { _ in try fn() }
  }
}
