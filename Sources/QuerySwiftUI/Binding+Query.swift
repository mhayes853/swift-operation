#if canImport(SwiftUI)
  import SwiftUI
  import Query

  extension Binding {
    @MainActor
    public init<State: QueryStateProtocol>(_ state: SwiftUI.State<State.StateValue>.Query<State>)
    where Value == State.StateValue {
      self = state.$state[HashableStore(store: state.store)]
    }
  }

  private final class HashableStore<State: QueryStateProtocol>: Hashable {
    let inner: QueryStore<State>

    init(store: QueryStore<State>) {
      self.inner = store
    }

    static func == (lhs: HashableStore<State>, rhs: HashableStore<State>) -> Bool {
      lhs.inner === rhs.inner
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(ObjectIdentifier(self.inner))
    }
  }

  extension QueryStateProtocol {
    fileprivate subscript(store: HashableStore<Self>) -> Self.StateValue {
      get { self.currentValue }
      set { store.inner.currentValue = newValue }
    }
  }
#endif
