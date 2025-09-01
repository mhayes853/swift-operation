// MARK: - OperationRequest

extension OperationRequest {
  /// Disables refetching this operation when the app re-enters from the background.
  ///
  /// - Parameter isDisabled: Whether or not to disable the refetching.
  /// - Returns: A ``ModifiedOperation``.
  public func disableApplicationActiveRerunning(
    _ isDisabled: Bool = true
  ) -> ModifiedOperation<Self, _DisableApplicationActiveReRunningModifier<Self>> {
    self.modifier(_DisableApplicationActiveReRunningModifier(isDisabled: isDisabled))
  }
}

public struct _DisableApplicationActiveReRunningModifier<
  Operation: OperationRequest
>: _ContextUpdatingOperationModifier {
  let isDisabled: Bool

  public func setup(context: inout OperationContext) {
    context.isApplicationActiveRerunningEnabled = !self.isDisabled
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// Whether or not a query will refetch its data when the app re-enters from the background.
  ///
  /// > Note: Setting this property through a ``OperationStore``'s ``OperationStore/context`` property has
  /// > no effect, rather use the ``OperationRequest/disableApplicationActiveRefetching(_:)`` modifier on your
  /// > query.
  ///
  /// The default value is true.
  public var isApplicationActiveRerunningEnabled: Bool {
    get { self[IsFocusRefetchingEnabledKey.self] }
    set { self[IsFocusRefetchingEnabledKey.self] = newValue }
  }

  private enum IsFocusRefetchingEnabledKey: Key {
    static let defaultValue = true
  }
}
