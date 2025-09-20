import Foundation

#if canImport(Combine)
  @preconcurrency import Combine
#endif

// MARK: - OperationStore

/// The runtime for a ``StatefulOperationRequest``.
///
/// `OperationStore`s are the runtime for your operation, and they manage its state and interactions to
/// make your operations usable in your UI. If you're using SwiftUI, `@State.Operation` subscribes
/// to a store under the hood to always have the latest data. If you're using
/// [Sharing](https://github.com/pointfreeco/swift-sharing), `@SharedOperation` also subscribes to
/// a store under the hood to always have the latest data.
///
/// You generally create `OperationStore` instances through ``OperationClient``, however you can
/// also create stand alone stores through one of the `detached` static initializers.
///
/// ```swift
/// let client = OperationClient()
/// let store = client.store(for: MyQuery())
///
/// let detachedStore = OperationStore.detached(query: MyQuery(), initialValue: nil)
/// ```
///
/// > Note: Stores created through a one of the `detached` initializers are not stored in a
/// > `OperationClient`. As a result, you will not be able to manage state on detached stores without
/// > keeping a direct reference to the store instance. See <doc:PatternMatchingAndStateManagement>
/// > for more.
///
/// Through an `OperationStore`, you can run your operation.
///
/// ```swift
/// let data = try await store.run()
/// ```
///
/// You can also subscribe to any state updates from the store using
/// ``subscribe(with:)-(OperationEventHandler<State>)``.
///
/// ```swift
/// let subscription = store.subscribe(
///   with: OperationEventHandler { state, context in
///     print("State Changed", state)
///   }
/// )
/// ```
///
/// > Note: Subscribing to the store will trigger the store to run the operation if the
/// > subscription is the first active subscription on the store and both ``isStale`` and
/// > ``isAutomaticRunningEnabled`` are true.
///
/// > Note: You can also subscribe to state updates via the Combine ``publisher`` or ``states``
/// > `AsyncSequence`.
///
/// You can also set the ``currentValue`` of the operation directly through the store. Setting the
/// value will push a state update to all subscribers of a store, which can keep your UI in sync.
///
/// ```swift
/// store.currentValue = MyOperationData()
/// ```
///
/// You can also place the operation in an error state via ``setResult(to:using:)``.
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
public final class OperationStore<State: OperationState & Sendable>: OperationPathable, Sendable {
  private struct Values {
    var state: State
    var taskHerdId: Int
    var context: OperationContext
    var controllerSubscription: OperationSubscription
    var subscribeTask: Task<State.OperationValue, any Error>?
  }

  #if swift(>=6.2)
    private let request: RequestActor
  #else
    private let request: RequestActor<State.OperationValue, State.Failure>
  #endif

  /// The ``OperationPath`` of the operation managed by this store.
  public let path: OperationPath

  private let values: RecursiveLock<Values>
  private let subscriptions: OperationSubscriptions<OperationEventHandler<State>>

  private init<Operation: StatefulOperationRequest>(
    operation: sending Operation,
    initialState: Operation.State,
    initialContext: OperationContext
  ) where State == Operation.State, State.OperationValue == Operation.Value {
    let subscriptions = OperationSubscriptions<OperationEventHandler<State>>()
    var context = initialContext
    operation.setup(context: &context)
    self.path = operation.path
    self.request = RequestActor(
      operation.handleEvents(with: OperationEventHandler(subscriptions: subscriptions))
    )
    self.values = RecursiveLock(
      Values(
        state: initialState,
        taskHerdId: 0,
        context: context,
        controllerSubscription: .empty,
        subscribeTask: nil
      )
    )
    self.subscriptions = subscriptions
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
  /// Detached stores are not connected to an ``OperationClient``. As such, accessing the
  /// ``OperationContext/operationClient`` context property in your operation will always yield a nil
  /// value.
  ///
  /// - Parameters:
  ///   - operation: The ``StatefulOperationRequest``.
  ///   - initialState: The initial state.
  ///   - initialContext: The default ``OperationContext``.
  /// - Returns: A store.
  public static func detached<Operation: StatefulOperationRequest>(
    operation: sending Operation,
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

// MARK: - Context

extension OperationStore {
  /// The ``OperationContext`` that is passed to the operation on every run.
  public var context: OperationContext {
    get { self.values.withLock { $0.context } }
    set { self.values.withLock { $0.context = newValue } }
  }
}

// MARK: - Automatic Fetching

extension OperationStore {
  /// Whether or not automatic running is enabled for this operation.
  ///
  /// Automatic running is defined as the process of running this operation without explicitly
  /// calling ``run(using:handler:)``. This includes, but not limited to:
  /// 1. Running when subscribed to via ``OperationStore/subscribe(with:)-(OperationEventHandler<State>)``.
  /// 2. Running when the app re-enters the foreground from the background.
  /// 3. Running when the user's network connection flips from offline to online.
  /// 4. Running via an ``OperationController``.
  /// 5. Running via the ``StatefulOperationRequest/rerunOnChange(of:)`` modifier.
  ///
  /// When automatic running is disabled, you are responsible for manually calling
  /// ``run(using:handler:)`` to ensure that your operation always has the latest
  /// data. Methods that work on specific operation types such as ``mutate(using:handler:)`` will
  /// call ``run(using:handler:)`` under the hood for you.
  ///
  /// When you use the default initializer of a ``OperationClient``, automatic running is enabled for all
  /// stores backed by ``QueryRequest`` and ``PaginatedRequest`` operations, and disabled for all
  /// stores backed by ``MutationRequest`` operations.
  ///
  /// Operations can individually enable or disable automatic fetching through the
  /// ``StatefulOperationRequest/enableAutomaticRunning(onlyWhen:)`` modifier.
  public var isAutomaticRunningEnabled: Bool {
    self.context.automaticRunningSpecification.isSatisfied(in: self.context)
  }
}

// MARK: - State

extension OperationStore {
  /// The current state of this operation.
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
  /// // ✅ No data races.
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
  /// The current value of the operation.
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
  /// Directly sets the result of the operation.
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
  /// Resets the state of the operation to its original values.
  ///
  /// > Important: This will cancel all active ``OperationTask``s on the operation. Those cancellations will not be
  /// > reflected in the reset operation state.
  ///
  /// - Parameter context: The ``OperationContext`` to reset the operation in.
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
  /// Whether or not the current data from the operation is considered stale.
  ///
  /// When this value is true, you should generally try to rerun the operation as soon as possible.
  /// ``subscribe(with:)-(OperationEventHandler<State>)`` will use this property to decide whether
  /// or not to automatically fetch the query's data when the first active subscription is made to
  /// this store.
  ///
  /// An operation can customize the value of this property via the
  /// ``StatefulOperationRequest/staleWhen(predicate:)`` modifier.
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
      context.runningOperationStore = OpaqueOperationStore(erasing: self)
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
      defer { task.inner.withLock { $0 = .finished } }
      do {
        let value = try await self.request.run(
          context: context,
          continuation: self.operationContinuation(
            task: task,
            initialHerdId: initialHerdId,
            context: context
          )
        )
        self.finishTask(
          with: .success(value as! State.OperationValue),
          task: task,
          initialHerdId: initialHerdId,
          context: context
        )
        return value as! State.OperationValue
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
    }
  }

  private func operationContinuation(
    task: LockedBox<TaskState>,
    initialHerdId: Int,
    context: OperationContext
  ) -> OperationContinuation<any Sendable, any Error> {
    OperationContinuation { result, yieldedContext in
      var context = yieldedContext ?? context
      context.operationResultUpdateReason = .yieldedResult
      self.editValuesWithStateChangeEvent(in: context) { [context] values in
        task.inner.withLock {
          switch $0 {
          case .finished:
            reportWarning(.queryYieldedAfterReturning(result))
          case .running(var task) where values.taskHerdId == initialHerdId:
            task.context = context
            values.state.update(
              with: result.map { $0 as! State.OperationValue }.mapError { $0 as! State.Failure },
              for: task
            )
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
  /// running the operation if both ``isStale`` and ``isAutomaticRunningEnabled`` are true. If
  /// the subscriber count drops to 0 whilst performing this initial run, then the run is cancelled
  /// and a `CancellationError` will be present on the ``state`` property.
  ///
  /// - Parameter handler: The event handler.
  /// - Returns: A ``OperationSubscription``.
  public func subscribe(with handler: OperationEventHandler<State>) -> OperationSubscription {
    let subscription = self.values.withLock { values in
      handler.onStateChanged?(self.state, self.context)
      let (subscription, isFirst) = self.subscriptions.add(handler: handler)
      if isFirst && self.isAutomaticRunningEnabled && self.isStale {
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

// MARK: - OperationActor

// NB: This weird contraption is required because just using an existential OperationRequest in
// here causes the compiler (Swift >=6.2) to complain about "sending" the "non-Sendable" Value
// generic. (That is literally required to be Sendable via constraints???)

#if swift(>=6.2)
  private final actor RequestActor {
    private let request:
      (isolated RequestActor, OperationContext, OperationContinuation<any Sendable, any Error>)
        async throws -> any Sendable

    init<Value: Sendable, Failure: Error>(
      _ operation: sending any OperationRequest<Value, Failure>
    ) {
      self.request = { isolation, context, continuation in
        try await operation.run(
          isolation: isolation,
          in: context,
          with: OperationContinuation { result, yieldedContext in
            continuation.yield(with: result.map { $0 }.mapError { $0 }, using: yieldedContext)
          }
        )
      }
    }

    func run(
      context: OperationContext,
      continuation: OperationContinuation<any Sendable, any Error>
    ) async throws -> any Sendable {
      try await self.request(self, context, continuation)
    }
  }
#else
  private final actor RequestActor<Value: Sendable, Failure: Error> {
    private let request: any OperationRequest<Value, Failure>

    init(_ operation: sending any OperationRequest<Value, Failure>) {
      self.request = operation
    }

    func run(
      context: OperationContext,
      continuation: OperationContinuation<any Sendable, any Error>
    ) async throws -> any Sendable {
      try await self.request.run(
        isolation: self,
        in: context,
        with: OperationContinuation { result, yieldedContext in
          continuation.yield(with: result.map { $0 }.mapError { $0 }, using: yieldedContext)
        }
      )
    }
  }
#endif

// MARK: - Event Handler

extension OperationEventHandler {
  fileprivate init(subscriptions: OperationSubscriptions<Self>) {
    self.init { state, context in
      subscriptions.forEach { $0.onStateChanged?(state, context) }
    } onRunStarted: { context in
      subscriptions.forEach { $0.onRunStarted?(context) }
    } onRunEnded: { context in
      subscriptions.forEach { $0.onRunEnded?(context) }
    } onResultReceived: { result, context in
      subscriptions.forEach { $0.onResultReceived?(result, context) }
    }
  }
}

// MARK: - Access OperationStore In Query

extension OperationContext {
  /// The current operation store that is fetching data.
  ///
  /// This property is only non-nil when accessed within an operation run, and it
  /// type erases the ``OperationStore`` that is running the operation.
  ///
  /// You can use this property to access the current state for your operation inside its body.
  /// ```swift
  /// struct MyQuery: QueryRequest, Hashable {
  ///   func fetch(
  ///     isolation: isolated (any Actor)?,
  ///     in context: OperationContext,
  ///     with continuation: OperationContinuation<Value, any Error>
  ///   ) async throws -> Value {
  ///     guard let store = context.runningOperationStore?.base as? OperationStore<State> else {
  ///       throw InvalidStoreError()
  ///     }
  ///     // 🟢 Can access the current value from within the query.
  ///     let currentValue = store.currentValue
  ///
  ///     // ...
  ///   }
  /// }
  /// ```
  public var runningOperationStore: OpaqueOperationStore? {
    get { self[CurrentOperationStoreKey.self] }
    set { self[CurrentOperationStoreKey.self] = newValue }
  }

  private enum CurrentOperationStoreKey: Key {
    static var defaultValue: OpaqueOperationStore? { nil }
  }
}

// MARK: - Warnings

extension OperationWarning {
  public static func queryYieldedAfterReturning<T, E>(_ result: Result<T, E>) -> Self {
    """
    An operation yielded a result to its continuation after it finished running.

        Result: \(result)

    This will not update the state of the operation inside its OperationStore. Avoid escaping \
    `OperationContinuation`s that are passed to an operation. If you would like to yield a result \
    when the operation is not running, consider using an `OperationController` instead.
    """
  }
}
