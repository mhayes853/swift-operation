import ConcurrencyExtras
import Foundation

// MARK: - Typealiases

public typealias QueryStoreFor<Query: QueryRequest> = QueryStore<
  Query.State
> where Query.State.QueryValue == Query.Value

// MARK: - QueryStore

@dynamicMemberLookup
public final class QueryStore<State: QueryStateProtocol>: Sendable {
  private typealias _State = (
    query: State, context: QueryContext, controllerSubscriptions: [QuerySubscription]
  )

  private let _query: any QueryRequest<State.QueryValue>
  private let _state: LockedBox<_State>
  private let subscriptions: QuerySubscriptions<QueryEventHandler<State.QueryValue>>

  private init<Query: QueryRequest>(
    query: Query,
    initialState: Query.State,
    initialContext: QueryContext
  ) where State == Query.State, State.QueryValue == Query.Value {
    self._query = query
    self._state = LockedBox(
      value: (query: initialState, context: initialContext, controllerSubscriptions: [])
    )
    self.subscriptions = QuerySubscriptions()
    self.setupQuery(with: initialContext)
  }

  deinit {
    self._state.inner.withLock {
      $0.controllerSubscriptions.forEach { $0.cancel() }
    }
  }

  private func setupQuery(with initialContext: QueryContext) {
    let controls = QueryControls<State>(
      context: { [weak self] in self?._state.inner.withLock { $0.context } ?? initialContext },
      onResult: { [weak self] result, context in
        self?._state.inner.withLock { $0.query.update(with: result, using: context) }
      },
      refetchTask: { [weak self] taskName, context in
        guard self?.isAutomaticFetchingEnabled == true else { return nil }
        return self?.fetchTask(name: taskName, using: context)
      }
    )
    self._state.inner.withLock { state in
      self._query.setup(context: &state.context)
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
    self._query.path
  }
}

// MARK: - Context

extension QueryStore {
  public var context: QueryContext {
    get { self._state.inner.withLock { $0.context } }
    set { self._state.inner.withLock { $0.context = newValue } }
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
    self._state.inner.withLock { $0.query }
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<State, NewValue>
  ) -> NewValue {
    self.state[keyPath: keyPath]
  }
}

// MARK: - Fetch

extension QueryStore {
  @discardableResult
  public func fetch(
    taskName: String? = nil,
    handler: QueryEventHandler<State.QueryValue> = QueryEventHandler(),
    using context: QueryContext? = nil
  ) async throws -> State.QueryValue {
    let (subscription, _) = self.subscriptions.add(handler: handler, isTemporary: true)
    defer { subscription.cancel() }
    let task = self.fetchTask(using: context)
    return try await task.runIfNeeded()
  }

  @discardableResult
  public func fetchTask(
    name: String? = nil,
    using context: QueryContext? = nil
  ) -> QueryTask<State.QueryValue> {
    self._state.inner.withLock { state in
      var context = context ?? state.context
      context.currentQueryStore = OpaqueQueryStore(erasing: self)
      let task = LockedBox<QueryTask<State.QueryValue>?>(value: nil)
      var inner = self.queryTask(name: name, in: context, using: task)
      task.inner.withLock { newTask in
        state.query.scheduleFetchTask(&inner)
        newTask = inner
      }
      return inner
    }
  }

  private func queryTask(
    name: String?,
    in context: QueryContext,
    using task: LockedBox<QueryTask<State.QueryValue>?>
  ) -> QueryTask<State.QueryValue> {
    let taskName =
      name ?? "\(typeName(Self.self, qualified: true, genericsAbbreviated: false)) Task"
    return QueryTask<State.QueryValue>(name: taskName, context: context) { context in
      self.subscriptions.forEach { $0.onFetchingStarted?(context) }
      defer { self.subscriptions.forEach { $0.onFetchingEnded?(context) } }
      do {
        let value = try await self._query.fetch(
          in: context,
          with: self.queryContinuation(task: task, context: context)
        )
        self._state.inner.withLock { state in
          task.inner.withLock {
            guard let task = $0 else { return }
            state.query.update(with: .success(value), for: task)
            state.query.finishFetchTask(task)
          }
          self.subscriptions.forEach { $0.onResultReceived?(.success(value), context) }
        }
        return value
      } catch {
        self._state.inner.withLock { state in
          task.inner.withLock {
            guard let task = $0 else { return }
            state.query.update(with: .failure(error), for: task)
            state.query.finishFetchTask(task)
          }
          self.subscriptions.forEach { $0.onResultReceived?(.failure(error), context) }
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
      self._state.inner.withLock { state in
        task.inner.withLock {
          guard let task = $0 else { return }
          state.query.update(with: result, for: task)
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
    with handler: QueryEventHandler<State.QueryValue>
  ) -> QuerySubscription {
    let (subscription, isFirstSubscriber) = self.subscriptions.add(handler: handler)
    if self.isAutomaticFetchingEnabled && isFirstSubscriber {
      Task { try await self.fetchTask().runIfNeeded() }
    }
    return subscription
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
