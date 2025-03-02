import ConcurrencyExtras
import Foundation

// MARK: - Typealiases

public typealias QueryStoreFor<
  Query: QueryProtocol
> = QueryStore<Query.State>

public typealias AnyQueryStore = QueryStore<QueryState<(any Sendable)?, any Sendable>>

// MARK: - QueryStore

@dynamicMemberLookup
public final class QueryStore<State: QueryStateProtocol>: Sendable {
  private typealias _State = (query: any QueryStateProtocol, context: QueryContext)

  private let _query: any QueryProtocol
  private let _state: LockedBox<_State>
  private let subscriptions: QuerySubscriptions<QueryEventHandler<any Sendable>>

  private init<Query: QueryProtocol>(
    query: Query,
    initialValue: State,
    initialContext: QueryContext
  ) {
    self._query = query
    self._state = LockedBox(value: (query: initialValue, context: initialContext))
    self.subscriptions = QuerySubscriptions()
    self._state.inner.withLock { query._setup(context: &$0.context) }
  }

  public init?(casting base: AnyQueryStore) {
    guard
      base._state.inner.withLock({
        $0.query.casted(to: State.StateValue.self, newQueryValue: State.QueryValue.self)
      }) != nil
    else {
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
    initialValue: Query.StateValue,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Query> where Query.State.StateValue == Query.StateValue {
    QueryStoreFor<Query>(
      query: query,
      initialValue: Query.State(initialValue: initialValue),
      initialContext: initialContext
    )
  }

  public static func detached<Query: QueryProtocol>(
    query: DefaultQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<DefaultQuery<Query>>
  where Query.State.StateValue == Query.StateValue, Query.Value == Query.StateValue {
    .detached(query: query, initialValue: query.defaultValue, initialContext: initialContext)
  }
}

extension AnyQueryStore {
  public static func detached<Query: QueryProtocol>(
    erasing query: Query,
    initialValue: (any Sendable)?,
    initialContext: QueryContext = QueryContext()
  ) -> AnyQueryStore {
    AnyQueryStore(
      query: query,
      initialValue: QueryState(initialValue: initialValue),
      initialContext: initialContext
    )
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
  public var willFetchOnFirstSubscription: Bool {
    self.context.enableAutomaticFetchingCondition.isEnabledByDefault
  }
}

// MARK: - State

extension QueryStore {
  public var state: State {
    self._state.inner.withLock {
      $0.query.casted(to: State.StateValue.self, newQueryValue: State.QueryValue.self) as! State
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
    handler: QueryEventHandler<State.QueryValue> = QueryEventHandler()
  ) async throws -> State.QueryValue {
    let (subscription, _) = self.subscriptions.add(handler: handler.erased(), isTemporary: true)
    defer { subscription.cancel() }
    let task = self.beginFetchTask()
    return try await task.cancellableValue as! State.QueryValue
  }

  @discardableResult
  private func beginFetchTask() -> Task<any Sendable, any Error> {
    self._state.inner.withLock { state in
      state.query.startFetchTask { [context = state.context] in
        self.subscriptions.forEach { $0.onFetchingStarted?() }
        defer { self.subscriptions.forEach { $0.onFetchingEnded?() } }
        do {
          let value = try await self._query.fetch(in: context) as! State.QueryValue
          self._state.inner.withLock { state in
            func open<S: QueryStateProtocol>(state: inout S) {
              state.endFetchTask(with: value as! S.StateValue)
            }
            open(state: &state.query)
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
    with handler: QueryEventHandler<State.QueryValue>
  ) -> QuerySubscription {
    let (subscription, isFirstSubscriber) = self.subscriptions.add(handler: handler.erased())
    if self.willFetchOnFirstSubscription && isFirstSubscriber {
      self.beginFetchTask()
    }
    return subscription
  }
}

// MARK: - Is Query Type

extension QueryStore {
  @available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
  public func query() -> any QueryProtocol<State.QueryValue> {
    self._query as! any QueryProtocol<State.QueryValue>
  }

  @_disfavoredOverload
  public func query() -> any QueryProtocol {
    self._query
  }
}
