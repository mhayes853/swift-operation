// MARK: - QueryStoreSubscriptions

final class QueryStoreSubscriptions<Value: Sendable>: Sendable {
  private typealias State = (currentId: Int, subscriptions: [Int: QueryStoreEventHandler<Value>])

  private let state = Lock<State>((currentId: 0, subscriptions: [:]))
}

// MARK: - Count

extension QueryStoreSubscriptions {
  var count: Int {
    self.state.withLock { $0.subscriptions.count }
  }
}

// MARK: - Subscribing

extension QueryStoreSubscriptions {
  func add(handler: QueryStoreEventHandler<Value>) -> (QueryStoreSubscription, isFirst: Bool) {
    self.state.withLock { state in
      let id = state.currentId
      defer { state.currentId += 1 }
      state.subscriptions[id] = handler
      let subscription = QueryStoreSubscription {
        _ = self.state.withLock { $0.subscriptions.removeValue(forKey: id) }
      }
      return (subscription, state.subscriptions.count == 1)
    }
  }
}

// MARK: - ForEach

extension QueryStoreSubscriptions {
  func forEach(
    _ body: (QueryStoreEventHandler<Value>) throws -> Void
  ) rethrows {
    try self.state.withLock { state in try state.subscriptions.forEach { try body($0.value) } }
  }
}
