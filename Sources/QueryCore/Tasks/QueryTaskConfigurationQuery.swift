extension QueryRequest {
  /// Sets the default ``QueryTaskConfiguration`` for this query.
  ///
  /// - Parameter configuration: The configuration to use.
  /// - Returns: A ``ModifiedQuery``.
  public func taskConfiguration(
    _ configuration: QueryTaskConfiguration
  ) -> ModifiedQuery<Self, _QueryTaskConfigurationModifier<Self>> {
    self.modifier(_QueryTaskConfigurationModifier { $0 = configuration })
  }

  /// Sets the default ``QueryTaskConfiguration`` for this query.
  ///
  /// - Parameter configuration: A function to modify the default configuration.
  /// - Returns: A ``ModifiedQuery``.
  public func taskConfiguration(
    _ editConfiguration: @escaping @Sendable (inout QueryTaskConfiguration) -> Void
  ) -> ModifiedQuery<Self, _QueryTaskConfigurationModifier<Self>> {
    self.modifier(_QueryTaskConfigurationModifier(editConfiguration: editConfiguration))
  }
}

public struct _QueryTaskConfigurationModifier<Query: QueryRequest>: _ContextUpdatingQueryModifier {
  let editConfiguration: @Sendable (inout QueryTaskConfiguration) -> Void

  public func setup(context: inout QueryContext) {
    self.editConfiguration(&context.queryTaskConfiguration)
  }
}
