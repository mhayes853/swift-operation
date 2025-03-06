struct MutationContextValues {
  var arguments: any Sendable
}

extension QueryContext {
  var mutationValues: MutationContextValues? {
    get { self[MutationContextValuesKey.self] }
    set { self[MutationContextValuesKey.self] = newValue }
  }

  private enum MutationContextValuesKey: Key {
    static var defaultValue: MutationContextValues? { nil }
  }
}
