// MARK: - OperationRequest

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

// MARK: - Satisfied Connection Status

extension OperationContext {
  /// The minimum satisfiable ``NetworkConnectionStatus`` status to satisfy
  /// ``NetworkConnectionRunSpecification``.
  ///
  /// The default value is ``NetworkConnectionStatus/connected``.
  public var satisfiedConnectionStatus: NetworkConnectionStatus {
    get { self[SatisfiedConnectionStatusKey.self] }
    set { self[SatisfiedConnectionStatusKey.self] = newValue }
  }

  private struct SatisfiedConnectionStatusKey: Key {
    static let defaultValue = NetworkConnectionStatus.connected
  }
}
