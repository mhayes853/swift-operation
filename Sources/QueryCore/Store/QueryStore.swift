import ConcurrencyExtras
import Foundation

// MARK: - Typealiases

public typealias QueryStoreFor<Query: QueryProtocol> = QueryStore<
  Query.StateValue, Query.Value
>

public typealias QueryStoreOf<Value: Sendable> = QueryStore<Value?, Value>

public typealias AnyQueryStore = QueryStoreOf<any Sendable>

// MARK: - QueryStore

@dynamicMemberLookup
public final class QueryStore<StateValue: Sendable, QueryValue: Sendable>: Sendable {
  private typealias State = (query: QueryState<any Sendable>, context: QueryContext)

  private let query: any QueryProtocol
  private let _state: LockedBox<State>
  private let subscriptions = QueryStoreSubscriptions<QueryValue>()

  private init<Query: QueryProtocol>(
    query: Query,
    initialValue: (any Sendable)?,
    initialContext: QueryContext
  ) {
    self.query = query
    self._state = LockedBox(value: (QueryState(initialValue: initialValue), initialContext))
    self._state.inner.withLock { query._setup(context: &$0.context) }
  }

  public init?(casting base: AnyQueryStore) {
    guard base._state.inner.withLock({ $0.query.casted(to: StateValue.self) }) != nil else {
      return nil
    }
    self.query = base.query
    self._state = base._state
  }
}

// MARK: - Detached

extension QueryStore {
  public static func detached<Query: QueryProtocol>(
    query: Query,
    initialValue: Query.StateValue,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Query> {
    QueryStoreFor<Query>(query: query, initialValue: initialValue, initialContext: initialContext)
  }

  public static func detached<Query: QueryProtocol>(
    query: DefaultQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<DefaultQuery<Query>> {
    .detached(query: query, initialValue: query.defaultValue, initialContext: initialContext)
  }
}

extension AnyQueryStore {
  public static func detached<Query: QueryProtocol>(
    erasing query: Query,
    initialValue: (any Sendable)?,
    initialContext: QueryContext = QueryContext()
  ) -> AnyQueryStore {
    AnyQueryStore(query: query, initialValue: initialValue, initialContext: initialContext)
  }

  public static func detached<Query: QueryProtocol>(
    erasing query: DefaultQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> AnyQueryStore {
    .detached(erasing: query, initialValue: query.defaultValue, initialContext: initialContext)
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
    get { self._state.inner.withLock { $0.context } }
    set { self._state.inner.withLock { $0.context = newValue } }
  }
}

// MARK: - Automatic Fetching

extension QueryStore {
  public var willFetchOnFirstSubscription: Bool {
    self.context.enableAutomaticFetchingCondition.isEnabledByDefault
  }
}

// MARK: - State

extension QueryStore {
  public var state: QueryState<StateValue> {
    self._state.inner.withLock { $0.query.casted(to: StateValue.self)! }
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<QueryState<StateValue>, NewValue>
  ) -> NewValue {
    self.state[keyPath: keyPath]
  }
}

// MARK: - Fetch

extension QueryStore {
  @discardableResult
  public func fetch(
    handler: QueryStoreEventHandler<QueryValue> = QueryStoreEventHandler()
  ) async throws -> QueryValue {
    let (subscription, _) = self.subscriptions.add(handler: handler, isTemporary: true)
    defer { subscription.cancel() }
    let task = self.beginFetchTask()
    return try await task.cancellableValue as! QueryValue
  }

  @discardableResult
  private func beginFetchTask() -> Task<any Sendable, any Error> {
    self._state.inner.withLock { state in
      state.query.startFetchTask { [context = state.context] in
        self.subscriptions.forEach { $0.onFetchingStarted?() }
        defer { self.subscriptions.forEach { $0.onFetchingEnded?() } }
        do {
          let value = try await self.query.fetch(in: context) as! QueryValue
          self._state.inner.withLock { state in
            state.query.endFetchTask(with: value as! StateValue)
            self.subscriptions.forEach { $0.onResultReceived?(.success(value)) }
          }
          return value
        } catch {
          self._state.inner.withLock { state in
            state.query.finishFetchTask(with: error)
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
    with eventHandler: QueryStoreEventHandler<QueryValue>
  ) -> QueryStoreSubscription {
    let (subscription, isFirstSubscriber) = self.subscriptions.add(handler: eventHandler)
    if self.willFetchOnFirstSubscription && isFirstSubscriber {
      self.beginFetchTask()
    }
    return subscription
  }
}
