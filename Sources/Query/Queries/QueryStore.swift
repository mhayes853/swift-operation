import Foundation

#if canImport(Combine)
  @preconcurrency import Combine
#endif

// MARK: - QueryStore

@dynamicMemberLookup
public final class QueryStore<State: QueryStateProtocol>: Sendable {
  private typealias Values = (
    query: State,
    taskHerdId: Int,
    context: QueryContext,
    controllerSubscriptions: [QuerySubscription]
  )

  private let query: any QueryRequest<State.QueryValue>
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
      (query: initialState, taskHerdId: 0, context: context, controllerSubscriptions: [])
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
  public static func detached<Query: QueryRequest>(
    query: Query,
    initialState: Query.State,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStore<Query.State>
  where State == Query.State, State.QueryValue == Query.Value {
    QueryStore<Query.State>(
      query: query,
      initialState: initialState,
      initialContext: initialContext
    )
  }

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

extension QueryStore {
  public var path: QueryPath {
    self.query.path
  }
}

// MARK: - Context

extension QueryStore {
  public var context: QueryContext {
    get { self.values.withLock { $0.context } }
    set { self.values.withLock { $0.context = newValue } }
  }
}

// MARK: - Automatic Fetching

extension QueryStore {
  public var isAutomaticFetchingEnabled: Bool {
    self.context.enableAutomaticFetchingCondition.isSatisfied(in: self.context)
  }
}

// MARK: - State

extension QueryStore {
  public var state: State {
    self.values.withLock { $0.query }
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<State, NewValue>
  ) -> NewValue {
    self.state[keyPath: keyPath]
  }

  public func withState<T: Sendable>(_ fn: (State) throws -> T) rethrows -> T {
    try self.values.withLock { try fn($0.query) }
  }
}

// MARK: - Current Value

extension QueryStore {
  public var currentValue: State.StateValue {
    get { self.state.currentValue }
    set {
      self.editValuesWithStateChangeEvent {
        $0.query.update(with: .success(newValue), using: $0.context)
      }
    }
  }
}

// MARK: - Set Result

extension QueryStore {
  public func setResult(
    to result: Result<State.StateValue, any Error>,
    using context: QueryContext? = nil
  ) {
    self.editValuesWithStateChangeEvent {
      $0.query.update(with: result, using: context ?? $0.context)
    }
  }
}

// MARK: - Reset

extension QueryStore {
  public func reset(using context: QueryContext? = nil) {
    self.editValuesWithStateChangeEvent { values in
      values.query.reset(using: context ?? values.context)
      values.taskHerdId += 1
    }
  }
}

// MARK: - Is Stale

extension QueryStore {
  public var isStale: Bool {
    self.isStale(using: self.context)
  }

  public func isStale(using context: QueryContext? = nil) -> Bool {
    self.values.withLock {
      $0.context.staleWhenRevalidateCondition.evaluate(state: $0.query, in: context ?? $0.context)
    }
  }
}

// MARK: - Fetch

extension QueryStore {
  @discardableResult
  public func fetch(
    using configuration: QueryTaskConfiguration? = nil,
    handler: QueryEventHandler<State> = QueryEventHandler()
  ) async throws -> State.QueryValue {
    let (subscription, _) = self.subscriptions.add(handler: handler, isTemporary: true)
    defer { subscription.cancel() }
    let task = self.fetchTask(using: configuration)
    return try await task.runIfNeeded()
  }

  @discardableResult
  public func fetchTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<State.QueryValue> {
    self.editValuesWithStateChangeEvent(in: configuration?.context) { values in
      var config = configuration ?? QueryTaskConfiguration(context: self.context)
      config.context.currentQueryStore = OpaqueQueryStore(erasing: self)
      config.name =
        config.name ?? "\(typeName(Self.self, qualified: true, genericsAbbreviated: false)) Task"
      let task = LockedBox<QueryTask<State.QueryValue>?>(value: nil)
      var inner = self.queryTask(
        configuration: config,
        initialHerdId: values.taskHerdId,
        using: task
      )
      task.inner.withLock { newTask in
        values.query.scheduleFetchTask(&inner)
        newTask = inner
      }
      return inner
    }
  }

  private func queryTask(
    configuration: QueryTaskConfiguration,
    initialHerdId: Int,
    using task: LockedBox<QueryTask<State.QueryValue>?>
  ) -> QueryTask<State.QueryValue> {
    QueryTask<State.QueryValue>(configuration: configuration) { info in
      self.subscriptions.forEach { $0.onFetchingStarted?(info.configuration.context) }
      defer { self.subscriptions.forEach { $0.onFetchingEnded?(info.configuration.context) } }
      do {
        let value = try await self.query.fetch(
          in: info.configuration.context,
          with: self.queryContinuation(
            task: task,
            initialHerdId: initialHerdId,
            context: info.configuration.context
          )
        )
        self.finishTask(
          with: .success(value),
          task: task,
          initialHerdId: initialHerdId,
          context: info.configuration.context
        )
        return value
      } catch {
        self.finishTask(
          with: .failure(error),
          task: task,
          initialHerdId: initialHerdId,
          context: info.configuration.context
        )
        throw error
      }
    }
  }

  private func finishTask(
    with result: Result<State.QueryValue, Error>,
    task: LockedBox<QueryTask<State.QueryValue>?>,
    initialHerdId: Int,
    context: QueryContext
  ) {
    self.editValuesWithStateChangeEvent(in: context) { values in
      var context = context
      context.queryResultUpdateReason = .returnedFinalResult
      task.inner.withLock {
        $0?.configuration.context = context
        guard let task = $0, values.taskHerdId == initialHerdId else { return }
        values.query.update(with: result, for: task)
        values.query.finishFetchTask(task)
      }
      self.subscriptions.forEach {
        $0.onResultReceived?(result, context)
      }
    }
  }

  private func queryContinuation(
    task: LockedBox<QueryTask<State.QueryValue>?>,
    initialHerdId: Int,
    context: QueryContext
  ) -> QueryContinuation<State.QueryValue> {
    QueryContinuation { result, yieldedContext in
      var context = yieldedContext ?? context
      context.queryResultUpdateReason = .yieldedResult
      self.editValuesWithStateChangeEvent(in: context) { [context] values in
        task.inner.withLock {
          guard let task = $0, values.taskHerdId == initialHerdId else { return }
          values.query.update(with: result, for: task)
        }
        self.subscriptions.forEach { $0.onResultReceived?(result, context) }
      }
    }
  }
}

// MARK: - Subscribe

extension QueryStore {
  public var subscriberCount: Int {
    self.subscriptions.count
  }

  public func subscribe(
    with handler: QueryEventHandler<State>
  ) -> QuerySubscription {
    handler.onStateChanged?(self.state, self.context)
    let (subscription, _) = self.subscriptions.add(handler: handler)
    if self.isAutomaticFetchingEnabled && self.isStale {
      let task = self.fetchTask()
      Task(configuration: task.configuration) { try await task.runIfNeeded() }
    }
    return subscription
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
        $0.onStateChanged?(values.query, context ?? values.context)
      }
      return value
    }
  }
}

// MARK: - Access QueryStore In Query

extension QueryContext {
  public var currentQueryStore: OpaqueQueryStore? {
    get { self[CurrentQueryStoreKey.self] }
    set { self[CurrentQueryStoreKey.self] = newValue }
  }

  private enum CurrentQueryStoreKey: Key {
    static var defaultValue: OpaqueQueryStore? { nil }
  }
}
