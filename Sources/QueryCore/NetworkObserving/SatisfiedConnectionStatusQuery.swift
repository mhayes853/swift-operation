extension QueryRequest {
  /// Indicates that the query runs completely offline, and therefore does not attempt to make any
  /// network connections.
  ///
  /// Some queries may not require access to the internet or an external network, and run entirely
  /// locally on the user's device. Examples of this may be running expensive and time-consuming
  /// computations from local file data on a background thread, running an expensive SQL query on a
  /// SQLite database, or streaming data from a locally running LLM.
  ///
  /// Using this modifier will prevent your query from being refetched when the user's network
  /// connection comes back online after being offline.
  ///
  /// - Returns: A ``ModifiedQuery``.
  public func completelyOffline() -> ModifiedQuery<Self, _SatisfiedConnectionStatusModifier<Self>> {
    self.satisfiedConnectionStatus(.disconnected)
  }
  
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

public struct _SatisfiedConnectionStatusModifier<Query: QueryRequest>: QueryModifier {
  let status: NetworkConnectionStatus

  public func setup(context: inout QueryContext, using query: Query) {
    context.satisfiedConnectionStatus = self.status
    query.setup(context: &context)
  }

  public func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await query.fetch(in: context, with: continuation)
  }
}
