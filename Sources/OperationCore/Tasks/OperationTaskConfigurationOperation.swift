extension OperationRequest {
  /// Sets the default ``OperationTaskConfiguration`` for this operation.
  ///
  /// - Parameter configuration: The configuration to use.
  /// - Returns: A ``ModifiedOperation``.
  public func taskConfiguration(
    _ configuration: OperationTaskConfiguration
  ) -> ModifiedOperation<Self, _OperationTaskConfigurationModifier<Self>> {
    self.modifier(_OperationTaskConfigurationModifier { $0 = configuration })
  }

  /// Sets the default ``OperationTaskConfiguration`` for this operation.
  ///
  /// - Parameter editConfiguration: A function to modify the default configuration.
  /// - Returns: A ``ModifiedOperation``.
  public func taskConfiguration(
    _ editConfiguration: @escaping @Sendable (inout OperationTaskConfiguration) -> Void
  ) -> ModifiedOperation<Self, _OperationTaskConfigurationModifier<Self>> {
    self.modifier(_OperationTaskConfigurationModifier(editConfiguration: editConfiguration))
  }
}

public struct _OperationTaskConfigurationModifier<
  Operation: OperationRequest
>: _ContextUpdatingOperationModifier {
  let editConfiguration: @Sendable (inout OperationTaskConfiguration) -> Void

  public func setup(context: inout OperationContext) {
    self.editConfiguration(&context.operationTaskConfiguration)
  }
}
