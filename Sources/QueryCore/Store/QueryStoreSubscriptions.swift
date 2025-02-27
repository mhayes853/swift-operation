// MARK: - QueryStoreSubscriptions

struct QueryStoreSubscriptions<Value: Sendable> {
  private var currentId = 0
  private var subscriptions = [QueryStoreSubscription.ID: QueryStoreEventHandler<Value>]()
}

// MARK: - Count

extension QueryStoreSubscriptions {
  var count: Int {
    self.subscriptions.count
  }
}

// MARK: - Subscribing

extension QueryStoreSubscriptions {
  mutating func add(handler: QueryStoreEventHandler<Value>) -> QueryStoreSubscription.ID {
    defer { self.currentId += 1 }
    self.subscriptions[self.currentId] = handler
    return self.currentId
  }

  mutating func cancel(id: QueryStoreSubscription.ID) {
    self.subscriptions.removeValue(forKey: id)
  }
}

// MARK: - ForEach

extension QueryStoreSubscriptions {
  func forEach(
    _ body: (QueryStoreEventHandler<Value>) throws -> Void
  ) rethrows {
    try self.subscriptions.forEach { try body($0.value) }
  }
}
