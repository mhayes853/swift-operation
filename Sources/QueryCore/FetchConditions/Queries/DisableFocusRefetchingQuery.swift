// MARK: - QueryRequest

extension QueryRequest {
  public func disableFocusRefetching(
    _ isDisabled: Bool = true
  ) -> ModifiedQuery<Self, DisableFocusRefetchingModifier<Self>> {
    self.modifier(DisableFocusRefetchingModifier(isDisabled: isDisabled))
  }
}

public struct DisableFocusRefetchingModifier<Query: QueryRequest>: QueryModifier {
  let isDisabled: Bool

  public func setup(context: inout QueryContext, using query: Query) {
    context.isFocusRefetchingEnabled = !self.isDisabled
  }

  public func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await query.fetch(in: context, with: continuation)
  }
}

// MARK: - QueryContext

extension QueryContext {
  public var isFocusRefetchingEnabled: Bool {
    get { self[IsFocusRefetchingEnabledKey.self] }
    set { self[IsFocusRefetchingEnabledKey.self] = newValue }
  }

  private enum IsFocusRefetchingEnabledKey: Key {
    static let defaultValue = true
  }
}
