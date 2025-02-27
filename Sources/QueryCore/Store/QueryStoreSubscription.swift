// MARK: - QueryStoreSubscription

public final class QueryStoreSubscription: Sendable {
  let store: AnyQueryStore
  let id: ID

  init(store: AnyQueryStore, id: QueryStoreSubscription.ID) {
    self.store = store
    self.id = id
  }

  deinit { self.cancel() }
}

// MARK: - Cancel

extension QueryStoreSubscription {
  public func cancel() {
    self.store.unsubscribe(subscription: self)
  }
}

// MARK: - ID

extension QueryStoreSubscription {
  typealias ID = Int
}
