#if canImport(SwiftUI)
  import SwiftUI
  import Operation

  // MARK: - Binding

  extension Binding {
    /// Creates a binding to the value of a ``SwiftUICore/State/Query`` value,
    ///
    /// - Parameter query: The query state to bind to.
    @MainActor
    public init<State: OperationState>(_ query: SwiftUI.State<State.StateValue>.Operation<State>)
    where Value == State.StateValue {
      self = query.$state[HashableStore(store: query.store)]
    }
  }

  // MARK: - HashableStore

  private final class HashableStore<State: OperationState>: Hashable {
    let inner: OperationStore<State>

    init(store: OperationStore<State>) {
      self.inner = store
    }

    static func == (lhs: HashableStore<State>, rhs: HashableStore<State>) -> Bool {
      lhs.inner === rhs.inner
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(ObjectIdentifier(self.inner))
    }
  }

  extension OperationState {
    fileprivate subscript(store: HashableStore<Self>) -> Self.StateValue {
      get { self.currentValue }
      set { store.inner.currentValue = newValue }
    }
  }
#endif
