extension QueryRequest {
  /// Indicates what level of ``NetworkConnectionStatus`` is necessary for this query to be
  /// considered as "connected to the network".
  ///
  /// - Parameter status: The ``NetworkConnectionStatus``.
  /// - Returns: A ``ModifiedQuery``.
  public func satisfiedConnectionStatus(
    _ status: NetworkConnectionStatus
  ) -> ModifiedQuery<Self, _SatisfiedConnectionStatusModifier<Self>> {
    self.modifier(_SatisfiedConnectionStatusModifier(status: status))
  }
}

public struct _SatisfiedConnectionStatusModifier<
  Query: QueryRequest
>: _ContextUpdatingQueryModifier {
  let status: NetworkConnectionStatus

  public func setup(context: inout OperationContext) {
    context.satisfiedConnectionStatus = self.status
  }
}
