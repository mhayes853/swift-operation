// MARK: - QueryRequest

extension QueryRequest {
  /// Disables refetching this query when the app re-enters from the background.
  ///
  /// - Parameter isDisabled: Whether or not to disable the refetching.
  /// - Returns: A ``ModifiedQuery``.
  public func disableApplicationActiveRefetching(
    _ isDisabled: Bool = true
  ) -> ModifiedQuery<Self, _DisableFocusRefetchingModifier<Self>> {
    self.modifier(_DisableFocusRefetchingModifier(isDisabled: isDisabled))
  }
}

public struct _DisableFocusRefetchingModifier<Query: QueryRequest>: QueryModifier {
  let isDisabled: Bool

  public func setup(context: inout QueryContext, using query: Query) {
    context.isApplicationActiveRefetchingEnabled = !self.isDisabled
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
  /// Whether or not a query will refetch its data when the app re-enters from the background.
  ///
  /// > Note: Setting this property through a ``QueryStore``'s ``QueryStore/context`` property has
  /// > no effect, rather use the ``QueryRequest/disableApplicationActiveRefetching(_:)`` modifier on your
  /// > query.
  ///
  /// The default value is true.
  public var isApplicationActiveRefetchingEnabled: Bool {
    get { self[IsFocusRefetchingEnabledKey.self] }
    set { self[IsFocusRefetchingEnabledKey.self] = newValue }
  }

  private enum IsFocusRefetchingEnabledKey: Key {
    static let defaultValue = true
  }
}
