import Foundation

#if canImport(Combine)
  @preconcurrency import Combine
#endif

// MARK: - QueryStore

/// The runtime for a ``QueryRequest``.
///
/// `QueryStore`s are the runtime for your queries, and they manage its state and interactions to
/// make your queries usable in your UI. If you're using SwiftUI, `@State.Query` subscribes to a store
/// under the hood to always have the latest data. If you're using [Sharing](https://github.com/pointfreeco/swift-sharing),
/// `@SharedQuery` also subscribes to a store under the hood to always have the latest data.
///
/// You generally create `QueryStore` instances through ``QueryClient``, however you can also
/// create stand alone stores through one of the ``detached(query:initialState:initialContext:)``
/// static initializers.
///
/// ```swift
/// let client = QueryClient()
/// let store = client.store(for: MyQuery())
///
/// let detachedStore = QueryStore.detached(MyQuery(), initialValue: nil)
/// ```
///
/// > Note: Stores created through a one of the `detached` initializers are not stored in a
/// > `QueryClient`. As a result, you will not be able to manage state on detached stores without
/// > keeping a direct reference to the store instance. See
/// > <doc:PatternMatchingAndStateManagement> for more.
///
/// Through a `QueryStore`, you can fetch your query's data.
///
/// ```swift
/// let data = try await store.fetch()
/// ```
///
/// You can also subscribe to any query state updates from the store using ``subscribe(with:)-93jyd``.
///
/// ```swift
/// let subscription = store.subscribe(
///   with: QueryEventHandler { state, context in
///     print("State Changed", state)
///   }
/// )
/// ```
///
/// > Note: Subscribing to the store will trigger the store to fetch data if the
/// > subscription is the first active subscription on the store and both ``isStale`` and
/// > ``isAutomaticFetchingEnabled`` are true.
///
/// > Note: You can also subscribe to state updates via the Combine ``publisher-swift.property``
/// > or ``states`` `AsyncSequence`.
///
/// You can also set the ``currentValue`` of the query directly through the store. Setting the
/// value will push a state update to all subscribers of a store, which can keep your UI in sync.
///
/// ```swift
/// store.currentValue = MyQueryData()
/// ```
///
/// You can also place the query in an error state via ``setResult(to:using:)``.
///
/// ```swift
/// store.setResult(to: .failure(SomeError()))
/// ```
///
/// The store also implements dynamic member lookup on its state. This allows you to access
/// state properties directly on the store like so.
///
/// ```swift
/// print("Is Loading", store.isLoading)
/// print("Error", store.error)
/// // ...
/// ```
@dynamicMemberLookup
public final class QueryStore<State: QueryStateProtocol>: Sendable {
  private struct Values {
    var state: State
    var taskHerdId: Int
    var context: QueryContext
    var controllerSubscriptions: [QuerySubscription]
    var subscribeTask: Task<State.QueryValue, any Error>?
  }

  private let query: any QueryRequest<State.QueryValue, State>
  private let values: RecursiveLock<Values>
  private let subscriptions: QuerySubscriptions<QueryEventHandler<State>>

  private init<Query: QueryRequest>(
    query: Query,
    initialState: Query.State,
    initialContext: QueryContext
  ) where State == Query.State, State.QueryValue == Query.Value {
    var context = initialContext
    query.setup(context: &context)
    self.query = query
    self.values = RecursiveLock(
      Values(
        state: initialState,
        taskHerdId: 0,
        context: context,
        controllerSubscriptions: [],
        subscribeTask: nil
      )
    )
    self.subscriptions = QuerySubscriptions()
    self.setupQuery(with: context, initialState: initialState)
  }

  deinit {
    self.values.withLock {
      $0.controllerSubscriptions.forEach { $0.cancel() }
    }
  }

  private func setupQuery(with initialContext: QueryContext, initialState: State) {
    let controls = QueryControls(
      store: self,
      defaultContext: initialContext,
      initialState: initialState
    )
    self.values.withLock { state in
      for controller in state.context.queryControllers {
        func open<C: QueryController>(_ controller: C) -> QuerySubscription {
          guard let controls = controls as? QueryControls<C.State> else { return .empty }
          return controller.control(with: controls)
        }
        state.controllerSubscriptions.append(open(controller))
      }
    }
  }
}

// MARK: - Detached

extension QueryStore {
  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``QueryClient``. As such, accessing the
  /// ``QueryContext/queryClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - query: The ``QueryRequest``.
  ///   - initialState: The initial state.
  ///   - initialContext: The default ``QueryContext``.
  /// - Returns: A store.
  public static func detached<Query: QueryRequest>(
    query: Query,
    initialState: Query.State,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStore<Query.State> where State == Query.State {
    QueryStore<Query.State>(
      query: query,
      initialState: initialState,
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
  ///   - query: The ``QueryRequest``.
  ///   - initialValue: The initial value.
  ///   - initialContext: The default ``QueryContext``.
  /// - Returns: A store.
  public static func detached<Query: QueryRequest>(
    query: Query,
    initialValue: Query.State.StateValue,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStore<Query.State>
  where
    Query.State == QueryState<Query.Value?, Query.Value>,
    State == QueryState<Query.Value?, Query.Value>
  {
    QueryStore<Query.State>(
      query: query,
      initialState: Query.State(initialValue: initialValue),
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
  ///   - query: The default ``QueryRequest``.
  ///   - initialContext: The default ``QueryContext``.
  /// - Returns: A store.
  public static func detached<Query: QueryRequest>(
    query: DefaultQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStore<DefaultQuery<Query>.State>
  where
    DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value>,
    State == DefaultQuery<Query>.State
  {
    QueryStore<DefaultQuery<Query>.State>(
      query: query,
      initialState: DefaultQuery<Query>.State(initialValue: query.defaultValue),
      initialContext: initialContext
    )
  }
}

// MARK: - Path

extension QueryStore: QueryPathable {
  /// The ``QueryPath`` of the query managed by this store.
  public var path: QueryPath {
    self.query.path
  }
}

// MARK: - Context

extension QueryStore {
  /// The ``QueryContext`` that is passed to the query every time ``fetch(using:handler:)`` is
  /// called.
  public var context: QueryContext {
    get { self.values.withLock { $0.context } }
    set { self.values.withLock { $0.context = newValue } }
  }
}

// MARK: - Automatic Fetching

extension QueryStore {
  /// Whether or not automatic fetching is enabled for this query.
  ///
  /// Automatic fetching is defined as the process of data being fetched from this query without
  /// explicitly calling ``QueryStore/fetch(using:handler:)``. This includes, but not limited to:
  /// 1. Automatically fetching from this query when subscribed to via ``QueryStore/subscribe(with:)-93jyd``.
  /// 2. Automatically fetching from this query when the app re-enters from the background.
  /// 3. Automatically fetching from this query when the user's network connection comes back online.
  /// 4. Automatically fetching from this query via a ``QueryController``.
  /// 5. Automatically fetching from this query via ``QueryRequest/refetchOnChange(of:)``.
  ///
  /// When automatic fetching is disabled, you are responsible for manually calling
  /// ``QueryStore/fetch(using:handler:)`` to ensure that your query always has the latest data.
  ///
  /// When you use the default initializer of a ``QueryClient``, automatic fetching is enabled for all
  /// ``QueryRequest`` conformances, and disabled for all ``MutationRequest`` conformances.
  ///
  /// Queries can individually enable or disable automatic fetching through the
  /// ``QueryRequest/enableAutomaticFetching(onlyWhen:)`` modifier.
  public var isAutomaticFetchingEnabled: Bool {
    self.context.enableAutomaticFetchingCondition.isSatisfied(in: self.context)
  }
}

// MARK: - State

extension QueryStore {
  /// The current state of this query.
  public var state: State {
    self.values.withLock { $0.state }
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<State, NewValue>
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
  /// let store: QueryStore<QueryState<Int, Int>>
  ///
  /// // 🔴 Is prone to high-level data races.
  /// store.currentValue += 1
  ///
  //  // ✅ No data races.
  /// store.withExclusiveAccess {
  ///   store.currentValue += 1
  /// }
  /// ```
  ///
  /// - Parameter fn: A closure with exclusive access to this store.
  /// - Returns: Whatever `fn` returns.
  public func withExclusiveAccess<T>(_ fn: () throws -> sending T) rethrows -> sending T {
    try self.values.withLock { _ in try fn() }
  }
}

// MARK: - Current Value

extension QueryStore {
  /// The current value of the query.
  public var currentValue: State.StateValue {
    get { self.state.currentValue }
    set {
      self.editValuesWithStateChangeEvent {
        $0.state.update(with: .success(newValue), using: $0.context)
      }
    }
  }
}

// MARK: - Set Result

extension QueryStore {
  /// Directly sets the result of a query.
  ///
  /// - Parameters:
  ///   - result: The `Result`.
  ///   - context: The ``QueryContext`` to set the result in.
  public func setResult(
    to result: Result<State.StateValue, any Error>,
    using context: QueryContext? = nil
  ) {
    self.editValuesWithStateChangeEvent {
      $0.state.update(with: result, using: context ?? $0.context)
    }
  }
}

// MARK: - Reset

extension QueryStore {
  /// Resets the state of the query to its original values.
  ///
  /// > Important: This will cancel all active ``QueryTask``s on the query. Those cancellations will not be
  /// > reflected in the reset query state.
  ///
  /// - Parameter context: The ``QueryContext`` to reset the query in.
  public func resetState(using context: QueryContext? = nil) {
    self.editValuesWithStateChangeEvent { values in
      values.state.reset(using: context ?? values.context)
      values.taskHerdId += 1
    }
  }
}

// MARK: - Is Stale

extension QueryStore {
  /// Whether or not the currently fetched data from the query is considered stale.
  ///
  /// When this value is true, you should generally try to refetch the query data as soon as
  /// possible. ``subscribe(with:)-93jyd`` will use this property to decide whether or not to
  /// automatically fetch the query's data when the first active subscription is made to this store.
  ///
  /// A query can customize the value of this property via the
  /// ``QueryRequest/staleWhen(predicate:)`` modifier.
  public var isStale: Bool {
    self.values.withLock {
      $0.context.staleWhenRevalidateCondition.evaluate(state: $0.state, in: $0.context)
    }
  }
}

// MARK: - Fetch

extension QueryStore {
  /// Fetches the query's data.
  ///
  /// - Parameters:
  ///   - context: The ``QueryContext`` to use for the underlying ``QueryTask``.
  ///   - handler: A ``QueryEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched data.
  @discardableResult
  public func fetch(
    using context: QueryContext? = nil,
    handler: QueryEventHandler<State> = QueryEventHandler()
  ) async throws -> State.QueryValue {
    let (subscription, _) = self.subscriptions.add(handler: handler, isTemporary: true)
    defer { subscription.cancel() }
    let task = self.fetchTask(using: context)
    return try await task.runIfNeeded()
  }

  /// Creates a ``QueryTask`` to fetch the query's data.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``QueryTask/runIfNeeded()`` to fetch the data.
  ///
  /// - Parameter context: The ``QueryContext`` for the task.
  /// - Returns: A task to fetch the query's data.
  @discardableResult
  public func fetchTask(using context: QueryContext? = nil) -> QueryTask<State.QueryValue> {
    self.editValuesWithStateChangeEvent(in: context) { values in
      var context = context ?? self.context
      context.currentQueryStore = OpaqueQueryStore(erasing: self)
      context.queryTaskConfiguration.name =
        context.queryTaskConfiguration.name
        ?? "\(typeName(Self.self, qualified: true, genericsAbbreviated: false)) Task"
      let task = LockedBox<TaskState>(value: .initial)
      var inner = self.queryTask(
        context: context,
        initialHerdId: values.taskHerdId,
        using: task
      )
      task.inner.withLock { newTask in
        values.state.scheduleFetchTask(&inner)
        newTask = .running(inner)
      }
      return inner
    }
  }

  private func queryTask(
    context: QueryContext,
    initialHerdId: Int,
    using task: LockedBox<TaskState>
  ) -> QueryTask<State.QueryValue> {
    QueryTask<State.QueryValue>(context: context) { _, context in
      self.subscriptions.forEach { $0.onFetchingStarted?(context) }
      defer {
        self.subscriptions.forEach { $0.onFetchingEnded?(context) }
        task.inner.withLock { $0 = .finished }
      }
      do {
        let value = try await self.query.fetch(
          in: context,
          with: self.queryContinuation(
            task: task,
            initialHerdId: initialHerdId,
            context: context
          )
        )
        self.finishTask(
          with: .success(value),
          task: task,
          initialHerdId: initialHerdId,
          context: context
        )
        return value
      } catch {
        self.finishTask(
          with: .failure(error),
          task: task,
          initialHerdId: initialHerdId,
          context: context
        )
        throw error
      }
    }
  }

  private func finishTask(
    with result: Result<State.QueryValue, Error>,
    task: LockedBox<TaskState>,
    initialHerdId: Int,
    context: QueryContext
  ) {
    self.editValuesWithStateChangeEvent(in: context) { values in
      var context = context
      context.queryResultUpdateReason = .returnedFinalResult
      task.inner.withLock {
        guard case .running(var task) = $0, values.taskHerdId == initialHerdId else { return }
        task.context.queryResultUpdateReason = .returnedFinalResult
        values.state.update(with: result, for: task)
        task.context.queryResultUpdateReason = nil
        values.state.finishFetchTask(task)
      }
      self.subscriptions.forEach {
        $0.onResultReceived?(result, context)
      }
    }
  }

  private func queryContinuation(
    task: LockedBox<TaskState>,
    initialHerdId: Int,
    context: QueryContext
  ) -> QueryContinuation<State.QueryValue> {
    QueryContinuation { result, yieldedContext in
      var context = yieldedContext ?? context
      context.queryResultUpdateReason = .yieldedResult
      self.editValuesWithStateChangeEvent(in: context) { [context] values in
        task.inner.withLock {
          switch $0 {
          case .finished:
            reportWarning(.queryYieldedAfterReturning(result))
          case .running(let task) where values.taskHerdId == initialHerdId:
            values.state.update(with: result, for: task)
            self.subscriptions.forEach { $0.onResultReceived?(result, context) }
          default:
            break
          }
        }
      }
    }
  }

  private enum TaskState {
    case initial
    case running(QueryTask<State.QueryValue>)
    case finished
  }
}

// MARK: - Subscribe

extension QueryStore {
  /// The total number of subscribers on this store.
  public var subscriberCount: Int {
    self.subscriptions.count
  }

  /// Subscribes to events from this store using a ``QueryEventHandler``.
  ///
  /// If the subscription is the first active subscription on this store, this method will begin
  /// fetching the query's data if both ``isStale`` and ``isAutomaticFetchingEnabled`` are true. If
  /// the subscriber count drops to 0 whilst performing this data fetch, then the fetch is
  /// cancelled and a `CancellationError` will be present on the ``state`` property.
  ///
  /// - Parameter handler: The event handler.
  /// - Returns: A ``QuerySubscription``.
  public func subscribe(with handler: QueryEventHandler<State>) -> QuerySubscription {
    let subscription = self.values.withLock { values in
      handler.onStateChanged?(self.state, self.context)
      let (subscription, isFirst) = self.subscriptions.add(handler: handler)
      if isFirst && self.isAutomaticFetchingEnabled && self.isStale {
        let task = self.fetchTask()
        values.subscribeTask = Task(configuration: task.configuration) {
          try await task.runIfNeeded()
        }
      }
      return subscription
    }
    return QuerySubscription {
      self.values.withLock { values in
        subscription.cancel()
        if self.subscriptions.count < 1 {
          values.subscribeTask?.cancel()
        }
      }
    }
  }
}

// MARK: - State

extension QueryStore {
  private func editValuesWithStateChangeEvent<T: Sendable>(
    in context: QueryContext? = nil,
    _ fn: @Sendable (inout Values) -> T
  ) -> T {
    self.values.withLock { values in
      let value = fn(&values)
      self.subscriptions.forEach {
        $0.onStateChanged?(values.state, context ?? values.context)
      }
      return value
    }
  }
}

// MARK: - Access QueryStore In Query

// TODO: - Make public in a way that makes sense.

extension QueryContext {
  var currentQueryStore: OpaqueQueryStore? {
    get { self[CurrentQueryStoreKey.self] }
    set { self[CurrentQueryStoreKey.self] = newValue }
  }

  private enum CurrentQueryStoreKey: Key {
    static var defaultValue: OpaqueQueryStore? { nil }
  }
}

// MARK: - Warnings

extension QueryWarning {
  public static func queryYieldedAfterReturning<T>(_ result: Result<T, any Error>) -> Self {
    """
    A query yielded a result to its continuation after returning.

        Result: \(result)

    This will not update the state of the query inside its QueryStore. Avoid escaping \
    `QueryContinuation`s that are passed to a query. If you would like to yield a result \
    after returning, consider using a `QueryController` instead.
    """
  }
}
