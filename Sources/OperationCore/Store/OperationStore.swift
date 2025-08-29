import Foundation

#if canImport(Combine)
  @preconcurrency import Combine
#endif

// MARK: - OperationStore

/// The runtime for a ``QueryRequest``.
///
/// `OperationStore`s are the runtime for your queries, and they manage its state and interactions to
/// make your queries usable in your UI. If you're using SwiftUI, `@State.Operation` subscribes to a store
/// under the hood to always have the latest data. If you're using [Sharing](https://github.com/pointfreeco/swift-sharing),
/// `@SharedOperation` also subscribes to a store under the hood to always have the latest data.
///
/// You generally create `OperationStore` instances through ``OperationClient``, however you can also
/// create stand alone stores through one of the ``detached(query:initialState:initialContext:)``
/// static initializers.
///
/// ```swift
/// let client = OperationClient()
/// let store = client.store(for: MyQuery())
///
/// let detachedStore = OperationStore.detached(MyQuery(), initialValue: nil)
/// ```
///
/// > Note: Stores created through a one of the `detached` initializers are not stored in a
/// > `OperationClient`. As a result, you will not be able to manage state on detached stores without
/// > keeping a direct reference to the store instance. See
/// > <doc:PatternMatchingAndStateManagement> for more.
///
/// Through a `OperationStore`, you can fetch your query's data.
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
public final class OperationStore<State: OperationState>: @unchecked Sendable {
  private struct Values {
    var state: State
    var taskHerdId: Int
    var context: OperationContext
    var controllerSubscription: OperationSubscription
    var subscribeTask: Task<State.OperationValue, any Error>?
  }

  // NB: Does not compile when adding '& Sendable' for some reason. We'll make the store
  // @unchecked Sendable because it can only be constructed with a Sendable operation.
  private let operation: any OperationRequest<State.OperationValue, State>

  private let values: RecursiveLock<Values>
  private let subscriptions: OperationSubscriptions<OperationEventHandler<State>>

  private init<Operation: OperationRequest & Sendable>(
    operation: Operation,
    initialState: Operation.State,
    initialContext: OperationContext
  ) where State == Operation.State, State.OperationValue == Operation.Value {
    var context = initialContext
    operation.setup(context: &context)
    self.operation = operation
    self.values = RecursiveLock(
      Values(
        state: initialState,
        taskHerdId: 0,
        context: context,
        controllerSubscription: .empty,
        subscribeTask: nil
      )
    )
    self.subscriptions = OperationSubscriptions()
    self.setupOperation(with: context, initialState: initialState)
  }

  deinit {
    self.values.withLock { $0.controllerSubscription.cancel() }
  }

  private func setupOperation(with initialContext: OperationContext, initialState: State) {
    let controls = OperationControls(
      store: self,
      defaultContext: initialContext,
      initialState: initialState
    )
    self.values.withLock { state in
      var subs = [OperationSubscription]()
      for controller in state.context.operationControllers {
        func open<C: OperationController>(_ controller: C) -> OperationSubscription {
          guard let controls = controls as? OperationControls<C.State> else { return .empty }
          return controller.control(with: controls)
        }
        subs.append(open(controller))
      }
      state.controllerSubscription = .combined(subs)
    }
  }
}

// MARK: - Detached

extension OperationStore {
  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``OperationClient``. As such, accessing the
  /// ``OperationContext/OperationClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - operation: The ``OperationRequest``.
  ///   - initialState: The initial state.
  ///   - initialContext: The default ``OperationContext``.
  /// - Returns: A store.
  public static func detached<Operation: OperationRequest & Sendable>(
    operation: Operation,
    initialState: Operation.State,
    initialContext: OperationContext = OperationContext()
  ) -> OperationStore<Operation.State> where State == Operation.State {
    OperationStore<Operation.State>(
      operation: operation,
      initialState: initialState,
      initialContext: initialContext
    )
  }
}

// MARK: - Path

extension OperationStore: OperationPathable {
  /// The ``OperationPath`` of the query managed by this store.
  public var path: OperationPath {
    self.operation.path
  }
}

// MARK: - Context

extension OperationStore {
  /// The ``OperationContext`` that is passed to the query every time ``fetch(using:handler:)`` is
  /// called.
  public var context: OperationContext {
    get { self.values.withLock { $0.context } }
    set { self.values.withLock { $0.context = newValue } }
  }
}

// MARK: - Automatic Fetching

extension OperationStore {
  /// Whether or not automatic fetching is enabled for this query.
  ///
  /// Automatic fetching is defined as the process of data being fetched from this query without
  /// explicitly calling ``OperationStore/fetch(using:handler:)``. This includes, but not limited to:
  /// 1. Automatically fetching from this query when subscribed to via ``OperationStore/subscribe(with:)-93jyd``.
  /// 2. Automatically fetching from this query when the app re-enters from the background.
  /// 3. Automatically fetching from this query when the user's network connection comes back online.
  /// 4. Automatically fetching from this query via a ``OperationController``.
  /// 5. Automatically fetching from this query via ``QueryRequest/refetchOnChange(of:)``.
  ///
  /// When automatic fetching is disabled, you are responsible for manually calling
  /// ``OperationStore/fetch(using:handler:)`` to ensure that your query always has the latest data.
  ///
  /// When you use the default initializer of a ``OperationClient``, automatic fetching is enabled for all
  /// ``QueryRequest`` conformances, and disabled for all ``MutationRequest`` conformances.
  ///
  /// Queries can individually enable or disable automatic fetching through the
  /// ``QueryRequest/enableAutomaticFetching(onlyWhen:)`` modifier.
  public var isAutomaticFetchingEnabled: Bool {
    self.context.enableAutomaticFetchingCondition.isSatisfied(in: self.context)
  }
}

// MARK: - State

extension OperationStore {
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
  /// let store: OperationStore<QueryState<Int, Int>>
  ///
  /// // 🔴 Is prone to high-level data races.
  /// store.currentValue += 1
  ///
  //  // ✅ No data races.
  /// store.withExclusiveAccess {
  ///   $0.currentValue += 1
  /// }
  /// ```
  ///
  /// - Parameter fn: A closure with exclusive access to this store.
  /// - Returns: Whatever `fn` returns.
  public func withExclusiveAccess<T>(
    _ fn: (OperationStore<State>) throws -> sending T
  ) rethrows -> sending T {
    try self.values.withLock { _ in try fn(self) }
  }
}

// MARK: - Current Value

extension OperationStore {
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

extension OperationStore {
  /// Directly sets the result of a query.
  ///
  /// - Parameters:
  ///   - result: The `Result`.
  ///   - context: The ``OperationContext`` to set the result in.
  public func setResult(
    to result: Result<State.StateValue, State.Failure>,
    using context: OperationContext? = nil
  ) {
    self.editValuesWithStateChangeEvent {
      $0.state.update(with: result, using: context ?? $0.context)
    }
  }
}

// MARK: - Reset

extension OperationStore {
  /// Resets the state of the query to its original values.
  ///
  /// > Important: This will cancel all active ``OperationTask``s on the query. Those cancellations will not be
  /// > reflected in the reset query state.
  ///
  /// - Parameter context: The ``OperationContext`` to reset the query in.
  public func resetState(using context: OperationContext? = nil) {
    let effect = self.editValuesWithStateChangeEvent { values in
      values.taskHerdId += 1
      return values.state.reset(using: context ?? values.context)
    }
    effect.tasksCancellable.cancel()
  }
}

// MARK: - Is Stale

extension OperationStore {
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

extension OperationStore {
  /// Runs the operation.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` to use for the underlying ``OperationTask``.
  ///   - handler: A ``OperationEventHandler`` to subscribe to events from fetching the data.
  ///     (This does not add an active subscriber to the store.)
  /// - Returns: The data returned from the operation.
  @discardableResult
  public func run(
    using context: OperationContext? = nil,
    handler: OperationEventHandler<State> = OperationEventHandler()
  ) async throws(State.Failure) -> State.OperationValue {
    let (subscription, _) = self.subscriptions.add(handler: handler, isTemporary: true)
    defer { subscription.cancel() }
    let task = self.runTask(using: context)
    return try await task.runIfNeeded()
  }

  /// Creates a ``OperationTask`` to run the operation.
  ///
  /// The returned task does not begin running immediately. Rather you must call
  /// ``OperationTask/runIfNeeded()`` to run the operation.
  ///
  /// - Parameter context: The ``OperationContext`` for the task.
  /// - Returns: A task to run the operation.
  public func runTask(
    using context: OperationContext? = nil
  ) -> OperationTask<State.OperationValue, State.Failure> {
    self.editValuesWithStateChangeEvent(in: context) { values in
      var context = context ?? self.context
      context.currentFetchingOperationStore = OpaqueOperationStore(erasing: self)
      context.operationTaskConfiguration.name =
        context.operationTaskConfiguration.name
        ?? "\(typeName(Self.self, qualified: true, genericsAbbreviated: false)) Task"
      let task = LockedBox<TaskState>(value: .initial)
      var inner = self.operationTask(
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

  private func operationTask(
    context: OperationContext,
    initialHerdId: Int,
    using task: LockedBox<TaskState>
  ) -> OperationTask<State.OperationValue, State.Failure> {
    OperationTask(context: context) { _, context in
      self.subscriptions.forEach { $0.onFetchingStarted?(context) }
      defer {
        self.subscriptions.forEach { $0.onFetchingEnded?(context) }
        task.inner.withLock { $0 = .finished }
      }
      do {
        let value = try await self.operation.run(
          isolation: #isolation,
          in: context,
          with: self.operationContinuation(
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
          with: .failure(error as! State.Failure),
          task: task,
          initialHerdId: initialHerdId,
          context: context
        )
        throw error
      }
    }
    .mapError { $0 as! State.Failure }
  }

  private func finishTask(
    with result: Result<State.OperationValue, State.Failure>,
    task: LockedBox<TaskState>,
    initialHerdId: Int,
    context: OperationContext
  ) {
    self.editValuesWithStateChangeEvent(in: context) { values in
      var context = context
      context.operationResultUpdateReason = .returnedFinalResult
      task.inner.withLock {
        guard case .running(var task) = $0, values.taskHerdId == initialHerdId else { return }
        task.context.operationResultUpdateReason = .returnedFinalResult
        values.state.update(with: result, for: task)
        task.context.operationResultUpdateReason = nil
        values.state.finishFetchTask(task)
      }
      self.subscriptions.forEach {
        $0.onResultReceived?(result.mapError { $0 as any Error }, context)
      }
    }
  }

  private func operationContinuation(
    task: LockedBox<TaskState>,
    initialHerdId: Int,
    context: OperationContext
  ) -> OperationContinuation<State.OperationValue> {
    OperationContinuation { result, yieldedContext in
      var context = yieldedContext ?? context
      context.operationResultUpdateReason = .yieldedResult
      self.editValuesWithStateChangeEvent(in: context) { [context] values in
        task.inner.withLock {
          switch $0 {
          case .finished:
            reportWarning(.queryYieldedAfterReturning(result))
          case .running(let task) where values.taskHerdId == initialHerdId:
            values.state.update(with: result.mapError { $0 as! State.Failure }, for: task)
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
    case running(OperationTask<State.OperationValue, State.Failure>)
    case finished
  }
}

// MARK: - Subscribe

extension OperationStore {
  /// The total number of subscribers on this store.
  public var subscriberCount: Int {
    self.subscriptions.count
  }

  /// Subscribes to events from this store using an ``OperationEventHandler``.
  ///
  /// If the subscription is the first active subscription on this store, this method will begin
  /// fetching the operation's data if both ``isStale`` and ``isAutomaticFetchingEnabled`` are true. If
  /// the subscriber count drops to 0 whilst performing this data fetch, then the fetch is
  /// cancelled and a `CancellationError` will be present on the ``state`` property.
  ///
  /// - Parameter handler: The event handler.
  /// - Returns: A ``OperationSubscription``.
  public func subscribe(with handler: OperationEventHandler<State>) -> OperationSubscription {
    let subscription = self.values.withLock { values in
      handler.onStateChanged?(self.state, self.context)
      let (subscription, isFirst) = self.subscriptions.add(handler: handler)
      if isFirst && self.isAutomaticFetchingEnabled && self.isStale {
        let task = self.runTask()
        values.subscribeTask = Task(configuration: task.configuration) {
          try await task.runIfNeeded()
        }
      }
      return subscription
    }
    return OperationSubscription {
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

extension OperationStore {
  private func editValuesWithStateChangeEvent<T: Sendable>(
    in context: OperationContext? = nil,
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

// MARK: - Access OperationStore In Query

extension OperationContext {
  /// The current query store that is fetching data.
  ///
  /// This property is only non-nil when accessed within ``QueryRequest/fetch(in:with:)``, and it
  /// type erases the ``OperationStore`` that is fetching its data.
  ///
  /// You can use this property to access the current state for your query inside its body.
  /// ```swift
  /// struct MyQuery: QueryRequest, Hashable {
  ///   func fetch(
  ///     in context: OperationContext,
  ///     with continuation: OperationContinuation<Value>
  ///   ) async throws -> Value {
  ///     guard let store = context.currentFetchingOperationStore?.base as? OperationStore<State> else {
  ///       throw InvalidStoreError()
  ///     }
  ///     // 🟢 Can access the current value from within the query.
  ///     let currentValue = store.currentValue
  ///
  ///     // ...
  ///   }
  /// }
  /// ```
  public var currentFetchingOperationStore: OpaqueOperationStore? {
    get { self[CurrentOperationStoreKey.self] }
    set { self[CurrentOperationStoreKey.self] = newValue }
  }

  private enum CurrentOperationStoreKey: Key {
    static var defaultValue: OpaqueOperationStore? { nil }
  }
}

// MARK: - Warnings

extension OperationWarning {
  public static func queryYieldedAfterReturning<T>(_ result: Result<T, any Error>) -> Self {
    """
    A query yielded a result to its continuation after returning.

        Result: \(result)

    This will not update the state of the query inside its OperationStore. Avoid escaping \
    `OperationContinuation`s that are passed to a query. If you would like to yield a result \
    after returning, consider using a `OperationController` instead.
    """
  }
}
