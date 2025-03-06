// MARK: - QueryStateLoader

protocol QueryStateLoader: Sendable {
  var currentState: any QueryStateProtocol { get }
}

extension QueryStateLoader {
  func state<State: QueryStateProtocol>(as type: State.Type) -> State {
    self.currentState as! State
  }
}

// MARK: - QueryStore Conformance

extension QueryStore: QueryStateLoader {
  var currentState: any QueryStateProtocol {
    self.state
  }
}

// MARK: - QueryContext

extension QueryContext {
  var queryStateLoader: QueryStateLoader? {
    get { self[QueryStateLoaderKey.self] }
    set { self[QueryStateLoaderKey.self] = newValue }
  }

  private enum QueryStateLoaderKey: Key {
    static var defaultValue: (any QueryStateLoader)? {
      nil
    }
  }
}
