import Operation

final class HashableStore<State: OperationState & Sendable>: Hashable {
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

extension OperationState where Self: Sendable {
  subscript(store: HashableStore<Self>) -> Self.StateValue {
    get { self.currentValue }
    set { store.inner.currentValue = newValue }
  }
}
