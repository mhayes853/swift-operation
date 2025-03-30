import Perception
import QueryCore
import SwiftNavigation

#if canImport(SwiftUI)
  import SwiftUI
#endif

// MARK: - QueryModel

@Perceptible
@MainActor
@dynamicMemberLookup
public final class QueryModel<State: QueryStateProtocol> {
  public private(set) var state: State

  public let store: QueryStore<State>

  private var subscription = QuerySubscription.empty

  #if canImport(SwiftUI)
    public var transaction = Transaction()
  #endif

  public var uiTransaction = UITransaction()

  public init(store: QueryStore<State>) {
    self.store = store
    self.state = store.state
    self.subscription = store.subscribe(
      with: QueryEventHandler { [weak self] state, _ in
        Task { @MainActor in
          guard let self else { return }
          self.withTransaction { self.state = state }
        }
      }
    )
  }
}

// MARK: - UITransaction Init

extension QueryModel {
  public convenience init(store: QueryStore<State>, uiTransaction: UITransaction) {
    self.init(store: store)
    self.uiTransaction = uiTransaction
  }
}

// MARK: - Dynamic Member Lookup

extension QueryModel {
  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.state[keyPath: keyPath]
  }
}

// MARK: - SwiftUI

#if canImport(SwiftUI)
  extension QueryModel {
    public var animation: Animation? {
      get { self.transaction.animation }
      set { self.transaction.animation = newValue }
    }

    public convenience init(store: QueryStore<State>, animation: Animation?) {
      self.init(store: store)
      self.animation = animation
    }

    public convenience init(store: QueryStore<State>, transaction: Transaction) {
      self.init(store: store)
      self.transaction = transaction
    }
  }
#endif

// MARK: - WithTransaction

extension QueryModel {
  private func withTransaction(_ body: () -> Void) {
    withUITransaction(self.uiTransaction) {
      #if canImport(SwiftUI)
        SwiftUI.withTransaction(self.transaction) {
          body()
        }
      #else
        body()
      #endif
    }
  }
}
