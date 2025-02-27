import Foundation

// MARK: - AnyQueryStore

@dynamicMemberLookup
public final class AnyQueryStore: Sendable {
  private typealias State = (
    query: QueryState<(any Sendable)?>,
    context: QueryContext,
    subscriptions: QueryStoreSubscriptions<any Sendable>
  )

  private let query: any QueryProtocol
  private let _state: Lock<State>

  init<Value>(
    query: some QueryProtocol<Value>,
    initialValue: Value?,
    initialContext: QueryContext
  ) {
    self.query = query
    self._state = Lock(
      (QueryState(initialValue: initialValue), initialContext, QueryStoreSubscriptions())
    )
    self._state.withLock { query._setup(context: &$0.context) }
  }
}

// MARK: - Path

extension AnyQueryStore {
  public var path: QueryPath {
    self.query.path
  }
}

// MARK: - Context

extension AnyQueryStore {
  public var context: QueryContext {
    get { self._state.withLock { $0.context } }
    set { self._state.withLock { $0.context = newValue } }
  }
}

// MARK: - Automatic Fetching

extension AnyQueryStore {
  public var isAutomaticFetchingEnabled: Bool {
    self.context.enableAutomaticFetchingCondition.isEnabledByDefault
  }
}

// MARK: - State

extension AnyQueryStore {
  public var state: QueryState<(any Sendable)?> {
    self._state.withLock { $0.query }
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<QueryState<(any Sendable)?>, NewValue>
  ) -> NewValue {
    self.state[keyPath: keyPath]
  }
}

// MARK: - Fetch

extension AnyQueryStore {
  @discardableResult
  public func fetch() async throws -> any Sendable {
    let task = self.beginFetchTask()
    return try await task.cancellableValue
  }

  @discardableResult
  private func beginFetchTask() -> Task<any Sendable, any Error> {
    self._state.withLock { state in
      state.query.startFetchTask { [context = state.context] in
        self._state.withLock { state in
          state.subscriptions.forEach { $0.onFetchingStarted?() }
        }
        defer {
          self._state.withLock { state in
            state.subscriptions.forEach { $0.onFetchingEnded?() }
          }
        }
        do {
          let value = try await self.query.fetch(in: context)
          self._state.withLock { state in
            state.query.endFetchTask(with: value)
            state.subscriptions.forEach { $0.onResultReceived?(.success(value)) }
          }
          return value
        } catch {
          self._state.withLock { state in
            state.query.endFetchTask(with: error)
            state.subscriptions.forEach { $0.onResultReceived?(.failure(error)) }
          }
          throw error
        }
      }
    }
  }
}

// MARK: - Subscribe

extension AnyQueryStore {
  public var subscriberCount: Int {
    self._state.withLock { $0.subscriptions.count }
  }

  public func subscribe(
    with eventHandler: QueryStoreEventHandler<any Sendable>
  ) -> QueryStoreSubscription {
    let (id, isFirstSubscriber) = self._state.withLock {
      ($0.subscriptions.add(handler: eventHandler), $0.subscriptions.count == 1)
    }
    if self.isAutomaticFetchingEnabled && isFirstSubscriber {
      self.beginFetchTask()
    }
    return QueryStoreSubscription(store: self, id: id)
  }

  func unsubscribe(subscription: QueryStoreSubscription) {
    self._state.withLock { $0.subscriptions.cancel(id: subscription.id) }
  }
}
