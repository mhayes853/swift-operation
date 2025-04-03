import Dependencies
import Query

// MARK: - StoreSubscriptionTracker

final class StoreSubscriptionTracker: Sendable {
  private typealias Entry = (
    subscription: QuerySubscription, handlers: [@Sendable (OpaqueQueryState, QueryContext) -> Void]
  )

  private let entries = RecursiveLock([ObjectIdentifier: Entry]())
}

// MARK: - Subscribe

extension StoreSubscriptionTracker {
  func subscribe<State>(
    to store: QueryStore<State>,
    with handler: QueryEventHandler<State>
  ) -> QuerySubscription {
    self.entries.withLock { entries in
      if var entry = entries[ObjectIdentifier(store)] {
        entry.handlers.append { state, context in
          handler.onStateChanged?(state.base as! State, context)
        }
        entries[ObjectIdentifier(store)] = entry
        return entry.subscription
      }
      let subscription = store.subscribe(
        with: QueryEventHandler { state, context in
          handler.onStateChanged?(state, context)
          self.entries.withLock {
            $0[ObjectIdentifier(store)]?.handlers
              .forEach { $0(OpaqueQueryState(state), context) }
          }
        }
      )
      entries[ObjectIdentifier(store)] = (subscription, [])
      return subscription
    }
  }
}

// MARK: - DependencyKey

extension StoreSubscriptionTracker: DependencyKey {
  static var liveValue: StoreSubscriptionTracker {
    StoreSubscriptionTracker()
  }

  static var testValue: StoreSubscriptionTracker {
    StoreSubscriptionTracker()
  }
}
