import Foundation

// MARK: - AnyQueryStore

@dynamicMemberLookup
public final class AnyQueryStore: Sendable {
  private typealias State = (query: QueryState<(any Sendable)?>, context: QueryContext)

  private let query: any QueryProtocol
  private let _state: Lock<State>

  init<Value>(
    query: some QueryProtocol<Value>,
    initialValue: Value?,
    initialContext: QueryContext
  ) {
    self.query = query
    self._state = Lock((QueryState(initialValue: initialValue), initialContext))
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
    let task = self._state.withLock { state in
      state.query.startFetchTask { [context = state.context] in
        do {
          let value = try await self.query.fetch(in: context)
          self._state.withLock { $0.query.endFetchTask(with: value) }
          return value
        } catch {
          self._state.withLock { $0.query.endFetchTask(with: error) }
          throw error
        }
      }
    }
    return try await task.cancellableValue
  }
}

// MARK: - Subscribe

extension AnyQueryStore {
  public func subscribe(
    _ fn: @Sendable @escaping (QueryStoreSubscription.Event<any Sendable>) -> Void
  ) -> QueryStoreSubscription {
    let id = self._state.withLock { $0.query.addSubscriber(fn) }
    return QueryStoreSubscription(store: self, id: id)
  }

  func unsubscribe(subscription: QueryStoreSubscription) {
    self._state.withLock { $0.query.removeSubscriber(id: subscription.id) }
  }
}
