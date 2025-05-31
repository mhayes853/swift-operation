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

public struct _QueryTaskConfigurationModifier<Query: QueryRequest>: QueryModifier {
  let configuration: QueryTaskConfiguration

  public func setup(context: inout QueryContext, using query: Query) {
    context.queryTaskConfiguration = self.configuration
  }

  public func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await query.fetch(in: context, with: continuation)
  }
}
