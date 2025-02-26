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

// MARK: - Event

extension QueryStoreSubscription {
  public enum Event<Value: Sendable>: Sendable {
    case idle
    case fetchingStarted
    case fetchingEnded
    case resultReceived(Result<Value, any Error>)
  }
}

// MARK: - ID

extension QueryStoreSubscription {
  typealias ID = Int
}
