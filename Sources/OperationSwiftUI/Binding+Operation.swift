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
#endif
