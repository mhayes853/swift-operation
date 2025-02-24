import Foundation

// MARK: - AnyQueryStore

@dynamicMemberLookup
public final class AnyQueryStore: Sendable {
  private let query: any QueryProtocol
  private let _state: Lock<QueryState<(any Sendable)?>>

  init<Value>(query: some QueryProtocol<Value>, initialValue: Value?) {
    self.query = query
    self._state = Lock(QueryState(initialValue: initialValue))
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
          let value = try await self.query.fetch(in: QueryContext())
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
