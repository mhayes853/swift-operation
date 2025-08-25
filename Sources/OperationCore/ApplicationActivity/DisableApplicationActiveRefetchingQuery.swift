// MARK: - QueryRequest

extension QueryRequest {
  /// Disables refetching this query when the app re-enters from the background.
  ///
  /// - Parameter isDisabled: Whether or not to disable the refetching.
  /// - Returns: A ``ModifiedQuery``.
  public func disableApplicationActiveRefetching(
    _ isDisabled: Bool = true
  ) -> ModifiedQuery<Self, _DisableApplicationActiveRefetchingModifier<Self>> {
    self.modifier(_DisableApplicationActiveRefetchingModifier(isDisabled: isDisabled))
  }
}

public struct _DisableApplicationActiveRefetchingModifier<
  Query: QueryRequest
>: _ContextUpdatingQueryModifier {
  let isDisabled: Bool

  public func setup(context: inout OperationContext) {
    context.isApplicationActiveRefetchingEnabled = !self.isDisabled
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// Whether or not a query will refetch its data when the app re-enters from the background.
  ///
  /// > Note: Setting this property through a ``OperationStore``'s ``OperationStore/context`` property has
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
