// MARK: - QueryState

struct QueryState<Value: Sendable>: Sendable {
  var value: Value
  var isLoading = false
  var error: (any Error)?
}

// MARK: - QueryStateStore

@dynamicMemberLookup
final class QueryStateStore<Value: Sendable>: Sendable {
  private let state: Lock<QueryState<Value>>

  init(initialValue: Value) {
    self.state = Lock(QueryState(value: initialValue))
  }
}

extension QueryStateStore {
  subscript<NewValue: Sendable>(
    dynamicMember keyPath: WritableKeyPath<QueryState<Value>, NewValue>
  ) -> NewValue {
    get { self.state.withLock { $0[keyPath: keyPath] } }
    set { self.state.withLock { $0[keyPath: keyPath] = newValue } }
  }
}
