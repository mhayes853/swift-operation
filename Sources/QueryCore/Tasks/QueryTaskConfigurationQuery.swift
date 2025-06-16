extension QueryRequest {
  /// Sets the default ``QueryTaskConfiguration`` for this query.
  ///
  /// - Parameter configuration: The configuration to use.
  /// - Returns: A ``ModifiedQuery``.
  public func taskConfiguration(
    _ configuration: QueryTaskConfiguration
  ) -> ModifiedQuery<Self, _QueryTaskConfigurationModifier<Self>> {
    self.modifier(_QueryTaskConfigurationModifier(configuration: configuration))
  }
}

public struct _QueryTaskConfigurationModifier<Query: QueryRequest>: _ContextUpdatingQueryModifier {
  let configuration: QueryTaskConfiguration

  public func setup(context: inout QueryContext) {
    context.queryTaskConfiguration = self.configuration
  }
}
