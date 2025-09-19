extension OperationRequest {
  /// Indicates that the operation runs completely offline, and therefore does not attempt to make any
  /// network connections.
  ///
  /// > Warning: Only use this modifier if your operation does not attempt to connect to the network in
  /// > any way shape or form. Otherwise, you'll lose out on benefits such as automatic rerunning
  /// > when the user's network comes back online after being offline.
  ///
  /// Some operation may not require access to the internet or an external network, and run entirely
  /// locally on the user's device. Examples of this may be running expensive and time-consuming
  /// computations from local file data on a background thread, running an expensive SQL query on a
  /// SQLite database, or streaming data from a locally running LLM.
  ///
  /// Attaching this modifier to your operation guarantees.
  /// - That ``OperationContext/satisfiedConnectionStatus`` is set to ``NetworkConnectionStatus/disconnected``.
  /// - That ``OperationContext/operationMaxRetries`` is set to 0.
  /// - That ``OperationContext/operationBackoffFunction`` is set to ``OperationBackoffFunction/noBackoff``.
  ///
  /// - Parameter isOffline: Whether the query is completely offline. Defaults to `true`. If
  ///   false, no modifications are made to the operation.
  /// - Returns: A ``ModifiedOperation``.
  public func completelyOffline(
    _ isOffline: Bool = true
  ) -> ModifiedOperation<Self, _CompletelyOfflineModifier<Self>> {
    self.modifier(_CompletelyOfflineModifier(isOffline: isOffline))
  }
}

public struct _CompletelyOfflineModifier<
  Operation: OperationRequest
>: _ContextUpdatingOperationModifier {
  let isOffline: Bool

  public func setup(context: inout OperationContext) {
    guard self.isOffline else { return }
    context.satisfiedConnectionStatus = .disconnected
    context.operationMaxRetries = 0
    context.operationBackoffFunction = .noBackoff
  }
}
