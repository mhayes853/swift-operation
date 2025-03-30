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

// MARK: - Dynamic Member Lookup

extension QueryModel {
  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.state[keyPath: keyPath]
  }
}

// MARK: - Animation

#if canImport(SwiftUI)
  extension QueryModel {
    public var animation: Animation? {
      get { self.transaction.animation }
      set { self.transaction.animation = newValue }
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
