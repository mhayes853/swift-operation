extension QueryRequest {
  /// Sets the default ``OperationTaskConfiguration`` for this query.
  ///
  /// - Parameter configuration: The configuration to use.
  /// - Returns: A ``ModifiedQuery``.
  public func taskConfiguration(
    _ configuration: OperationTaskConfiguration
  ) -> ModifiedQuery<Self, _OperationTaskConfigurationModifier<Self>> {
    self.modifier(_OperationTaskConfigurationModifier { $0 = configuration })
  }

  /// Sets the default ``OperationTaskConfiguration`` for this query.
  ///
  /// - Parameter editConfiguration: A function to modify the default configuration.
  /// - Returns: A ``ModifiedQuery``.
  public func taskConfiguration(
    _ editConfiguration: @escaping @Sendable (inout OperationTaskConfiguration) -> Void
  ) -> ModifiedQuery<Self, _OperationTaskConfigurationModifier<Self>> {
    self.modifier(_OperationTaskConfigurationModifier(editConfiguration: editConfiguration))
  }
}

public struct _OperationTaskConfigurationModifier<Query: QueryRequest>:
  _ContextUpdatingQueryModifier
{
  let editConfiguration: @Sendable (inout OperationTaskConfiguration) -> Void

  public func setup(context: inout OperationContext) {
    self.editConfiguration(&context.operationTaskConfiguration)
  }
}
