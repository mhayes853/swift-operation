import ConcurrencyExtras
import Foundation

// MARK: - Typealiases

public typealias QueryStoreFor<Query: QueryProtocol> = QueryStore<
  Query.State
> where Query.State.QueryValue == Query.Value

// MARK: - QueryStore

@dynamicMemberLookup
public final class QueryStore<State: QueryStateProtocol>: Sendable {
  private typealias _State = (query: State, context: QueryContext)

  private let _query: any QueryProtocol<State.QueryValue>
  private let _state: LockedBox<_State>
  private let subscriptions: QuerySubscriptions<QueryEventHandler<State.QueryValue>>

  private init<Query: QueryProtocol>(
    query: Query,
    initialState: Query.State,
    initialContext: QueryContext
  ) where State == Query.State, State.QueryValue == Query.Value {
    self._query = query
    self._state = LockedBox(value: (query: initialState, context: initialContext))
    self.subscriptions = QuerySubscriptions()
    self._state.inner.withLock { query._setup(context: &$0.context) }
  }

  public init?(casting store: OpaqueQueryStore) {
    guard let store = store.base as? QueryStore<State> else {
      return nil
    }
    self._query = store._query
    self._state = store._state
    self.subscriptions = store.subscriptions
  }
}

// MARK: - Detached

extension QueryStore {
  public static func detached<Query: QueryProtocol>(
    query: Query,
    initialState: Query.State,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Query> {
    QueryStoreFor<Query>(query: query, initialState: initialState, initialContext: initialContext)
  }

  public static func detached<Query: QueryProtocol>(
    query: Query,
    initialValue: Query.State.StateValue,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Query> where Query.State == QueryState<Query.Value?, Query.Value> {
    .detached(
      query: query,
      initialState: Query.State(initialValue: initialValue),
      initialContext: initialContext
    )
  }

  public static func detached<Query: QueryProtocol>(
    query: DefaultQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<DefaultQuery<Query>>
  where DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value> {
    .detached(
      query: query,
      initialState: DefaultQuery<Query>.State(initialValue: query.defaultValue),
      initialContext: initialContext
    )
  }

  public static func detached<Query: InfiniteQueryProtocol>(
    query: Query,
    initialValue: Query.State.StateValue,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Query> {
    .detached(
      query: query,
      initialState: InfiniteQueryState(
        initialValue: initialValue,
        initialPageId: query.initialPageId
      ),
      initialContext: initialContext
    )
  }

  public static func detached<Query: InfiniteQueryProtocol>(
    query: DefaultInfiniteQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Query> {
    .detached(
      query: query,
      initialState: InfiniteQueryState(
        initialValue: query.defaultValue,
        initialPageId: query.initialPageId
      ),
      initialContext: initialContext
    )
  }

  public static func detached<Mutation: MutationProtocol>(
    mutation: Mutation,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Mutation> {
    .detached(
      query: mutation,
      initialState: MutationState(),
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
    handler: QueryEventHandler<State.QueryValue> = QueryEventHandler(),
    using context: QueryContext? = nil
  ) async throws -> State.QueryValue {
    let (subscription, _) = self.subscriptions.add(handler: handler, isTemporary: true)
    defer { subscription.cancel() }
    let task = self.fetchTask(using: context)
    return try await task.runIfNeeded()
  }

  @discardableResult
  public func fetchTask(using context: QueryContext? = nil) -> QueryTask<State.QueryValue> {
    self._state.inner.withLock { state in
      var context = context ?? state.context
      context.currentQueryStore = self
      let task = LockedBox<QueryTask<State.QueryValue>?>(value: nil)
      let inner = self.queryTask(in: context, using: task)
      return task.inner.withLock { newTask in
        newTask = inner
        return state.query.fetchTaskStarted(inner)
      }
    }
  }

  private func queryTask(
    in context: QueryContext,
    using task: LockedBox<QueryTask<State.QueryValue>?>
  ) -> QueryTask<State.QueryValue> {
    QueryTask<State.QueryValue>(context: context) { context in
      self.subscriptions.forEach { $0.onFetchingStarted?(context) }
      defer { self.subscriptions.forEach { $0.onFetchingEnded?(context) } }
      do {
        let value = try await self._query.fetch(in: context)
        self._state.inner.withLock { state in
          task.inner.withLock {
            guard let task = $0 else { return }
            state.query.fetchTaskEnded(task, with: .success(value))
          }
          self.subscriptions.forEach { $0.onResultReceived?(.success(value), context) }
        }
        return value
      } catch {
        self._state.inner.withLock { state in
          task.inner.withLock {
            guard let task = $0 else { return }
            state.query.fetchTaskEnded(task, with: .failure(error))
          }
          self.subscriptions.forEach { $0.onResultReceived?(.failure(error), context) }
        }
        throw error
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

extension QueryProtocol where State.QueryValue == Value {
  public func currentQueryStore(in context: QueryContext) -> QueryStoreFor<Self>? {
    context.currentQueryStore as? QueryStoreFor<Self>
  }
}

extension QueryContext {
  fileprivate var currentQueryStore: (any Sendable)? {
    get { self[CurrentQueryStoreKey.self] }
    set { self[CurrentQueryStoreKey.self] = newValue }
  }

  private enum CurrentQueryStoreKey: Key {
    static var defaultValue: (any Sendable)? { nil }
  }
}
