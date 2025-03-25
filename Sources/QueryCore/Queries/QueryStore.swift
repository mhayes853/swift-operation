import ConcurrencyExtras
import Foundation

// MARK: - Typealiases

public typealias QueryStoreFor<Query: QueryRequest> = QueryStore<
  Query.State
> where Query.State.QueryValue == Query.Value

// MARK: - QueryStore

@dynamicMemberLookup
public final class QueryStore<State: QueryStateProtocol>: Sendable {
  private typealias Values = (
    query: State,
    taskCohortId: Int,
    context: QueryContext,
    controllerSubscriptions: [QuerySubscription]
  )

  private let query: any QueryRequest<State.QueryValue>
  private let values: Lock<Values>
  private let subscriptions: QuerySubscriptions<QueryEventHandler<State>>

  private init<Query: QueryRequest>(
    query: Query,
    initialState: Query.State,
    initialContext: QueryContext
  ) where State == Query.State, State.QueryValue == Query.Value {
    var context = initialContext
    query.setup(context: &context)
    self.query = query
    self.values = Lock(
      (query: initialState, taskCohortId: 0, context: context, controllerSubscriptions: [])
    )
    self.subscriptions = QuerySubscriptions()
    self.setupQuery(with: context)
  }

  deinit {
    self.values.withLock {
      $0.controllerSubscriptions.forEach { $0.cancel() }
    }
  }

  private func setupQuery(with initialContext: QueryContext) {
    let controls = QueryControls<State>(
      context: { [weak self] in self?.values.withLock { $0.context } ?? initialContext },
      onResult: { [weak self] in self?.setResult(to: $0, using: $1) },
      refetchTask: { [weak self] configuration in
        guard self?.isAutomaticFetchingEnabled == true else { return nil }
        return self?.fetchTask(using: configuration)
      },
      onReset: { [weak self] in self?.reset(using: $0) }
    )
    self.values.withLock { state in
      for controller in state.context.queryControllers {
        func open<C: QueryController>(_ controller: C) -> QuerySubscription {
          controller.control(with: controls as! QueryControls<C.State>)
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
  ) -> QueryStoreFor<Query> {
    QueryStoreFor<Query>(query: query, initialState: initialState, initialContext: initialContext)
  }

  public static func detached<Query: QueryRequest>(
    query: Query,
    initialValue: Query.State.StateValue,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Query> where Query.State == QueryState<Query.Value?, Query.Value> {
    QueryStoreFor<Query>(
      query: query,
      initialState: Query.State(initialValue: initialValue),
      initialContext: initialContext
    )
  }

  public static func detached<Query: QueryRequest>(
    query: DefaultQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<DefaultQuery<Query>>
  where DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value> {
    QueryStoreFor<DefaultQuery<Query>>(
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
      values.taskCohortId += 1
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
        initialCohortId: values.taskCohortId,
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
    initialCohortId: Int,
    using task: LockedBox<QueryTask<State.QueryValue>?>
  ) -> QueryTask<State.QueryValue> {
    QueryTask<State.QueryValue>(configuration: configuration) { info in
      self.subscriptions.forEach { $0.onFetchingStarted?(info.configuration.context) }
      defer { self.subscriptions.forEach { $0.onFetchingEnded?(info.configuration.context) } }
      do {
        let value = try await self.query.fetch(
          in: info.configuration.context,
          with: self.queryContinuation(task: task, context: info.configuration.context)
        )
        self.editValuesWithStateChangeEvent(in: info.configuration.context) { values in
          task.inner.withLock {
            guard let task = $0 else { return }
            values.query.update(with: .success(value), for: task)
            values.query.finishFetchTask(task)
          }
          self.subscriptions.forEach {
            $0.onResultReceived?(.success(value), info.configuration.context)
          }
        }
        return value
      } catch {
        self.editValuesWithStateChangeEvent(in: info.configuration.context) { values in
          let cohortId = values.taskCohortId
          task.inner.withLock {
            guard let task = $0, cohortId == initialCohortId else { return }
            values.query.update(with: .failure(error), for: task)
            values.query.finishFetchTask(task)
          }
          self.subscriptions.forEach {
            $0.onResultReceived?(.failure(error), info.configuration.context)
          }
        }
        throw error
      }
    }
  }

  private func queryContinuation(
    task: LockedBox<QueryTask<State.QueryValue>?>,
    context: QueryContext
  ) -> QueryContinuation<State.QueryValue> {
    var context = context
    context.queryResultUpdateReason = .yieldedResult
    return QueryContinuation { [context] result in
      self.editValuesWithStateChangeEvent(in: context) { values in
        task.inner.withLock {
          guard let task = $0 else { return }
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
    let (subscription, isFirstSubscriber) = self.subscriptions.add(handler: handler)
    if self.isAutomaticFetchingEnabled && isFirstSubscriber {
      Task { try await self.fetchTask().runIfNeeded() }
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
