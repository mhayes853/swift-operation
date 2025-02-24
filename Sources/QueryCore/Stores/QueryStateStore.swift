import Foundation

// MARK: - QueryState

struct QueryState<Value: Sendable>: Sendable {
  var value: Value
  var valueUpdateCount = 0
  var valueLastUpdatedAt: Date?
  var isLoading = false
  var error: (any Error)?
  var errorUpdateCount = 0
  var errorLastUpdatedAt: Date?
  var fetchTask: Task<Value, any Error>?
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
  func update<T: Sendable>(_ fn: (inout QueryState<Value>) throws -> T) rethrows -> T {
    try self.state.withLock { try fn(&$0) }
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
