import ConcurrencyExtras
import Foundation

// MARK: - QueryStore

@dynamicMemberLookup
public final class AnyQueryStore: Sendable {
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
}

// MARK: - Detached

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
    initialValue: Query.State.StateValue,
    initialContext: QueryContext = QueryContext()
  ) -> AnyQueryStore
  where Query.State == QueryState<Query.Value?, Query.Value> {
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
    DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value>
  {
    .detached(
      erasing: query,
      initialState: DefaultQuery<Query>.State(initialValue: query.defaultValue),
      initialContext: initialContext
    )
  }

  public static func detached<Query: InfiniteQueryProtocol>(
    erasing query: Query,
    initialValue: Query.State.StateValue,
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

  public static func detached<Mutation: MutationProtocol>(
    erasing mutation: Mutation,
    initialContext: QueryContext = QueryContext()
  ) -> AnyQueryStore {
    .detached(
      erasing: mutation,
      initialState: MutationState(),
      initialContext: initialContext
    )
  }
}

// MARK: - Path

extension AnyQueryStore {
  public var path: QueryPath {
    self._query.path
  }
}

// MARK: - Context

extension AnyQueryStore {
  public var context: QueryContext {
    get { self._state.inner.withLock { $0.context } }
    set { self._state.inner.withLock { $0.context = newValue } }
  }
}

// MARK: - Automatic Fetching

extension AnyQueryStore {
  public var isAutomaticFetchingEnabled: Bool {
    self.context.enableAutomaticFetchingCondition.isSatisfied(in: self.context)
  }
}

// MARK: - State

extension AnyQueryStore {
  public var state: AnyQueryState {
    self._state.inner.withLock { $0.query }
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<AnyQueryState, NewValue>
  ) -> NewValue {
    self.state[keyPath: keyPath]
  }
}

// MARK: - Fetch

extension AnyQueryStore {
  @discardableResult
  public func fetch(
    handler: QueryEventHandler<any Sendable> = QueryEventHandler(),
    using context: QueryContext? = nil
  ) async throws -> any Sendable {
    let (subscription, _) = self.subscriptions.add(handler: handler.erased(), isTemporary: true)
    defer { subscription.cancel() }
    let task = self.fetchTask(using: context)
    return try await task.runIfNeeded()
  }

  @discardableResult
  public func fetchTask(using context: QueryContext? = nil) -> QueryTask<any Sendable> {
    self._state.inner.withLock { state in
      var context = context ?? state.context
      context.currentStore = self
      let task = Lock<QueryTask<any Sendable>?>(nil)
      return task.withLock { newTask in
        let inner = QueryTask<any Sendable>(context: context) { context in
          self.subscriptions.forEach { $0.onFetchingStarted?(context) }
          defer { self.subscriptions.forEach { $0.onFetchingEnded?(context) } }
          do {
            let value = try await self._query.fetch(in: context)
            self._state.inner.withLock { state in
              task.withLock {
                guard let task = $0 else { return }
                state.query.fetchTaskEnded(task, with: .success(value))
              }
              self.subscriptions.forEach { $0.onResultReceived?(.success(value), context) }
            }
            return value
          } catch {
            self._state.inner.withLock { state in
              task.withLock {
                guard let task = $0 else { return }
                state.query.fetchTaskEnded(task, with: .failure(error))
              }
              self.subscriptions.forEach { $0.onResultReceived?(.failure(error), context) }
            }
            throw error
          }
        }
        newTask = inner
        return state.query.fetchTaskStarted(inner)
      }
    }
  }
}

// MARK: - Subscribe

extension AnyQueryStore {
  public var subscriberCount: Int {
    self.subscriptions.count
  }

  public func subscribe(
    with handler: QueryEventHandler<any Sendable>
  ) -> QuerySubscription {
    let (subscription, isFirstSubscriber) = self.subscriptions.add(handler: handler.erased())
    if self.isAutomaticFetchingEnabled && isFirstSubscriber {
      Task { try await self.fetchTask().runIfNeeded() }
    }
    return subscription
  }
}
