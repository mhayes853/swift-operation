// MARK: - QueryStoreSubscriptions

final class QueryStoreSubscriptions<Value: Sendable>: Sendable {
  private typealias Handler = (isTemporary: Bool, handler: QueryStoreEventHandler<Value>)
  private typealias State = (currentId: Int, handlers: [Int: Handler])

  private let state = Lock<State>((currentId: 0, handlers: [:]))
}

// MARK: - Count

extension QueryStoreSubscriptions {
  var count: Int {
    self.state.withLock { self.handlersCount(in: $0) }
  }

  private func handlersCount(in state: State) -> Int {
    state.handlers.count { !$0.value.isTemporary }
  }
}

// MARK: - Subscribing

extension QueryStoreSubscriptions {
  func add(
    handler: QueryStoreEventHandler<Value>,
    isTemporary: Bool = false
  ) -> (QueryStoreSubscription, isFirst: Bool) {
    self.state.withLock { state in
      let id = state.currentId
      defer { state.currentId += 1 }
      state.handlers[id] = (isTemporary, handler)
      let subscription = QueryStoreSubscription {
        _ = self.state.withLock { $0.handlers.removeValue(forKey: id) }
      }
      return (subscription, self.handlersCount(in: state) == 1)
    }
  }
}

// MARK: - ForEach

extension QueryStoreSubscriptions {
  func forEach(
    _ body: (QueryStoreEventHandler<Value>) throws -> Void
  ) rethrows {
    try self.state.withLock { state in
      try state.handlers.forEach { try body($0.value.handler) }
    }
  }
}
