// MARK: - OperationRequest

extension OperationRequest {
  /// Disables rerunning this operation when the app re-enters from the background.
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
  /// Whether or not an operation will rerun when the app re-enters from the background.
  ///
  /// The default value is true.
  public var isApplicationActiveRerunningEnabled: Bool {
    get { self[IsApplicationActiveRerunningEnabled.self] }
    set { self[IsApplicationActiveRerunningEnabled.self] = newValue }
  }

  private enum IsApplicationActiveRerunningEnabled: Key {
    static let defaultValue = true
  }
}
