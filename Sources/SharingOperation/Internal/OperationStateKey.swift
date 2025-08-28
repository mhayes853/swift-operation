import Dependencies
import Foundation
import IdentifiedCollections
import Operation
import Sharing

// MARK: - OperationStateKey

struct OperationStateKey<
  State: OperationState,
  Scheduler: SharedOperationStateScheduler
>: SharedKey {
  private let store: OperationStore<State>
  let id = OperationStateKeyID()
  private let scheduler: Scheduler

  init(store: OperationStore<State>, scheduler: Scheduler) {
    self.store = store
    self.scheduler = scheduler
  }

  typealias Value = OperationStateKeyValue<State>

  func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
    switch context {
    case .initialValue:
      continuation.resume(returning: Value(store: self.store))
    case .userInitiated:
      Task<Void, Never> {
        do {
          try await self.store.run()
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
      with: OperationEventHandler { state, _ in
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

// MARK: - OperationStateKeyID

final class OperationStateKeyID: Sendable {
}

extension OperationStateKeyID: Equatable {
  static func == (lhs: OperationStateKeyID, rhs: OperationStateKeyID) -> Bool {
    lhs === rhs
  }
}

extension OperationStateKeyID: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

// MARK: - OperationStateKeyValue

struct OperationStateKeyValue<State: OperationState> {
  var currentValue: State.StateValue
  let store: OperationStore<State>

  init(store: OperationStore<State>) {
    self.store = store
    self.currentValue = store.currentValue
  }
}
