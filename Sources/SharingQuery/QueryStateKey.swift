import Dependencies
import Foundation
import IdentifiedCollections
import Query
import Sharing

#if canImport(SwiftUI)
  import SwiftUI
#endif

// MARK: - QueryStateKey

struct QueryStateKey<State: QueryStateProtocol> {
  private let store: QueryStore<State>
  let id = QueryStateKeyID()
  #if canImport(SwiftUI)
    private let animation: Animation?
  #endif

  init(store: QueryStore<State>) {
    self.store = store
    #if canImport(SwiftUI)
      self.animation = nil
    #endif
  }
}

#if canImport(SwiftUI)
  extension QueryStateKey {
    init(store: QueryStore<State>, animation: Animation) {
      self.store = store
      self.animation = animation
    }
  }
#endif

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
          self.scheduleYield { continuation.resume(returning: Value(store: self.store)) }
        } catch {
          self.scheduleYield { continuation.resume(throwing: error) }
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
        self.scheduleYield {
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

  private func scheduleYield(_ fn: @escaping @Sendable () -> Void) {
    #if canImport(SwiftUI)
      if let animation {
        Task { @MainActor in
          withAnimation(animation) {
            fn()
          }
        }
      } else {
        fn()
      }
    #else
      fn()
    #endif
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
