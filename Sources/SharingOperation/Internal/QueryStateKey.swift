import Dependencies
import Foundation
import IdentifiedCollections
import Operation
import Sharing

// MARK: - QueryStateKey

struct QueryStateKey<State: QueryStateProtocol, Scheduler: SharedQueryStateScheduler> {
  private let store: QueryStore<State>
  let id = QueryStateKeyID()
  private let scheduler: Scheduler

  init(store: QueryStore<State>, scheduler: Scheduler) {
    self.store = store
    self.scheduler = scheduler
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
          self.scheduler.schedule { continuation.resume(returning: Value(store: self.store)) }
        } catch {
          self.scheduler.schedule { continuation.resume(throwing: error) }
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
      with: QueryEventHandler { state, _ in
        self.scheduler.schedule {
          let value = Value(store: self.store)
          subscriber.yield(value)
          if let error = state.error {
            subscriber.yield(throwing: error)
          }
          subscriber.yieldLoading(state.isLoading)
        }
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
