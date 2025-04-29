import Dependencies
import Foundation
import IdentifiedCollections
import Query
import Sharing

// MARK: - QueryStateKey

struct QueryStateKey<State: QueryStateProtocol> {
  private let store: QueryStore<State>
  let id = QueryStateKeyID()

  init(store: QueryStore<State>) {
    self.store = store
  }
}

extension QueryStateKey: SharedKey {
  typealias Value = QueryStateKeyValue<State>

  func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
    switch context {
    case .initialValue:
      continuation.resume(returning: Value(store: self.store))
    case .userInitiated:
      Task<Void, Never> {
        do {
          try await self.store.fetch()
          continuation.resume(returning: Value(store: self.store))
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  func save(_ value: Value, context: SaveContext, continuation: SaveContinuation) {
    self.store.currentValue = value.currentValue
    continuation.resume()
  }

  func subscribe(
    context: LoadContext<Value>,
    subscriber: SharedSubscriber<Value>
  ) -> SharedSubscription {
    let subscription = self.store.subscribe(
      with: QueryEventHandler { _, _ in
        subscriber.yield(Value(store: self.store))
      }
    )
    return SharedSubscription { subscription.cancel() }
  }
}

// MARK: - QueryStateKeyID

final class QueryStateKeyID: Sendable {
}

extension QueryStateKeyID: Equatable {
  static func == (lhs: QueryStateKeyID, rhs: QueryStateKeyID) -> Bool {
    lhs === rhs
  }
}

extension QueryStateKeyID: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

// MARK: - QueryStateKeyValue

struct QueryStateKeyValue<State: QueryStateProtocol> {
  var currentValue: State.StateValue
  let store: QueryStore<State>

  init(store: QueryStore<State>) {
    self.store = store
    self.currentValue = store.currentValue
  }
}
