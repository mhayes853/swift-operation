struct MutationContextValues: Sendable {
  var arguments: any Sendable
}

extension QueryContext {
  var mutationValues: MutationContextValues? {
    get { self[MutationContextValuesKey.self] }
    set { self[MutationContextValuesKey.self] = newValue }
  }

  func mutationArgs<T: Sendable>(as: T.Type) -> T? {
    self.mutationValues?.arguments as? T
  }

  private enum MutationContextValuesKey: Key {
    static var defaultValue: MutationContextValues? { nil }
  }
}
