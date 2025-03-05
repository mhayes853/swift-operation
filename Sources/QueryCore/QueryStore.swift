import ConcurrencyExtras
import Foundation

// MARK: - Typealiases

public typealias QueryStoreFor<Query: QueryProtocol> = QueryStore<Query.State>

public typealias AnyQueryStore = QueryStore<AnyQueryState>

// MARK: - QueryStore

@dynamicMemberLookup
public final class QueryStore<State: QueryStateProtocol>: Sendable {
  private typealias _State = (query: AnyQueryState, context: QueryContext)

  private let _query: any QueryProtocol
  private let _state: LockedBox<_State>
  private let subscriptions: QuerySubscriptions<QueryEventHandler<any Sendable>>

  private init<Query: QueryProtocol>(
    query: Query,
    initialState: AnyQueryState,
    initialContext: QueryContext
  ) {
    self._query = query
    self._state = LockedBox(value: (query: initialState, context: initialContext))
    self.subscriptions = QuerySubscriptions()
    self._state.inner.withLock { query._setup(context: &$0.context) }
  }

  public init?(casting base: AnyQueryStore) {
    guard base._state.inner.withLock({ $0.query.base as? State }) != nil else {
      return nil
    }
    self._query = base._query
    self._state = base._state
    self.subscriptions = base.subscriptions
  }
}

// MARK: - Detached

extension QueryStore {
  public static func detached<Query: QueryProtocol>(
    query: Query,
    initialState: Query.State,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Query> {
    QueryStoreFor<Query>(
      query: query,
      initialState: AnyQueryState(initialState),
      initialContext: initialContext
    )
  }

  public static func detached<Query: QueryProtocol>(
    query: Query,
    initialValue: Query.StateValue,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Query> where Query.State == QueryState<Query.StateValue, Query.Value> {
    QueryStoreFor<Query>(
      query: query,
      initialState: AnyQueryState(Query.State(initialValue: initialValue)),
      initialContext: initialContext
    )
  }

  public static func detached<Query: QueryProtocol>(
    query: DefaultQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<DefaultQuery<Query>>
  where DefaultQuery<Query>.State == QueryState<DefaultQuery<Query>.StateValue, Query.Value> {
    .detached(query: query, initialValue: query.defaultValue, initialContext: initialContext)
  }

  public static func detached<Query: InfiniteQueryProtocol>(
    query: Query,
    initialValue: Query.StateValue,
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
}

extension AnyQueryStore {
  public static func detached<Query: QueryProtocol>(
    erasing query: Query,
    initialState: Query.State,
    initialContext: QueryContext = QueryContext()
  ) -> AnyQueryStore {
    AnyQueryStore(
      query: query,
      initialState: AnyQueryState(initialState),
      initialContext: initialContext
    )
  }

  public static func detached<Query: QueryProtocol>(
    erasing query: Query,
    initialValue: Query.StateValue,
    initialContext: QueryContext = QueryContext()
  ) -> AnyQueryStore
  where Query.State == QueryState<Query.StateValue, Query.Value> {
    .detached(
      erasing: query,
      initialState: QueryState(initialValue: initialValue),
      initialContext: initialContext
    )
  }

  public static func detached<Query: QueryProtocol>(
    erasing query: DefaultQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> AnyQueryStore
  where
    DefaultQuery<Query>.State == QueryState<DefaultQuery<Query>.StateValue, Query.Value>
  {
    .detached(
      erasing: query,
      initialState: DefaultQuery<Query>.State(initialValue: query.defaultValue),
      initialContext: initialContext
    )
  }

  public static func detached<Query: InfiniteQueryProtocol>(
    erasing query: Query,
    initialValue: Query.StateValue,
    initialContext: QueryContext = QueryContext()
  ) -> AnyQueryStore {
    .detached(
      erasing: query,
      initialState: InfiniteQueryState(
        initialValue: initialValue,
        initialPageId: query.initialPageId
      ),
      initialContext: initialContext
    )
  }

  public static func detached<Query: InfiniteQueryProtocol>(
    erasing query: DefaultInfiniteQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> AnyQueryStore {
    .detached(
      erasing: query,
      initialState: InfiniteQueryState(
        initialValue: query.defaultValue,
        initialPageId: query.initialPageId
      ),
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
    self.context.enableAutomaticFetchingCondition.isEnabledByDefault
  }
}

// MARK: - State

extension QueryStore {
  public var state: State {
    self._state.inner.withLock { state in
      if let query = state.query as? State {
        return query
      }
      return state.query.base as! State
    }
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
    let (subscription, _) = self.subscriptions.add(handler: handler.erased(), isTemporary: true)
    defer { subscription.cancel() }
    let task = self.beginFetchTask(using: context)
    return try await task.cancellableValue as! State.QueryValue
  }

  @discardableResult
  private func beginFetchTask(using context: QueryContext? = nil) -> Task<any Sendable, any Error> {
    self._state.inner.withLock { state in
      let context = context ?? state.context
      return state.query.startFetchTask(in: context) {
        self.subscriptions.forEach { $0.onFetchingStarted?() }
        defer { self.subscriptions.forEach { $0.onFetchingEnded?() } }
        do {
          let value = try await self._query.fetch(in: context)
          self._state.inner.withLock { state in
            func open<S: QueryStateProtocol>(state: inout S) {
              state.endFetchTask(in: context, with: .success(value as! S.QueryValue))
            }
            open(state: &state.query)
            self.subscriptions.forEach { $0.onResultReceived?(.success(value)) }
          }
          return value
        } catch {
          self._state.inner.withLock { state in
            state.query.endFetchTask(in: context, with: .failure(error))
            self.subscriptions.forEach { $0.onResultReceived?(.failure(error)) }
          }
          throw error
        }
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
    let (subscription, isFirstSubscriber) = self.subscriptions.add(handler: handler.erased())
    if self.isAutomaticFetchingEnabled && isFirstSubscriber {
      self.beginFetchTask()
    }
    return subscription
  }
}
