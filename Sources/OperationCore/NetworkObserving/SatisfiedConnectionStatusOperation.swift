extension OperationRequest {
  /// Indicates what level of ``NetworkConnectionStatus`` is necessary for this operation to be
  /// considered "connected to the network".
  ///
  /// - Parameter status: The ``NetworkConnectionStatus``.
  /// - Returns: A ``ModifiedOperation``.
  public func satisfiedConnectionStatus(
    _ status: NetworkConnectionStatus
  ) -> ModifiedOperation<Self, _SatisfiedConnectionStatusModifier<Self>> {
    self.modifier(_SatisfiedConnectionStatusModifier(status: status))
  }
}

public struct _SatisfiedConnectionStatusModifier<
  Operation: OperationRequest
>: _ContextUpdatingOperationModifier {
  let status: NetworkConnectionStatus

  public func setup(context: inout OperationContext) {
    context.satisfiedConnectionStatus = self.status
  }
}
