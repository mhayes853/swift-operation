final class MutationContextValues: Sendable {
  private let state: Lock<(any Sendable)?>

  init() {
    self.state = Lock(nil)
  }

  init(arguments: any Sendable) {
    self.state = Lock(arguments)
  }

  var arguments: (any Sendable)? {
    get { self.state.withLock { $0 } }
    set { self.state.withLock { $0 = newValue } }
  }
}

extension QueryContext {
  var mutationValues: MutationContextValues {
    get { self[MutationContextValuesKey.self] }
    set { self[MutationContextValuesKey.self] = newValue }
  }

  func mutationArgs<T: Sendable>(as: T.Type) -> T? {
    self.mutationValues.arguments as? T
  }

  private enum MutationContextValuesKey: Key {
    static var defaultValue: MutationContextValues { MutationContextValues() }
  }
}
