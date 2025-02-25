import Foundation

// MARK: - AnyQueryStore

@dynamicMemberLookup
public final class AnyQueryStore: Sendable {
  private let query: any QueryProtocol
  public let context: QueryContext
  private let _state: Lock<QueryState<(any Sendable)?>>

  init<Value>(
    query: some QueryProtocol<Value>,
    initialValue: Value?,
    initialContext: QueryContext
  ) {
    self.query = query
    self.context = initialContext
    self._state = Lock(QueryState(initialValue: initialValue))
  }
}

// MARK: - Path

extension AnyQueryStore {
  public var path: QueryPath {
    self.query.path
  }
}

// MARK: - State

extension AnyQueryStore {
  public var state: QueryState<(any Sendable)?> {
    self._state.withLock { $0 }
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
      state.startFetchTask {
        do {
          let value = try await self.query.fetch(in: self.context)
          self._state.withLock { $0.endFetchTack(with: value) }
          return value
        } catch {
          self._state.withLock { $0.endFetchTask(with: error) }
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
    let id = self._state.withLock { $0.addSubscriber(fn) }
    return QueryStoreSubscription(store: self, id: id)
  }

  func unsubscribe(subscription: QueryStoreSubscription) {
    self._state.withLock { $0.removeSubscriber(id: subscription.id) }
  }
}
