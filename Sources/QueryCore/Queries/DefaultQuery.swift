extension QueryRequest {
  /// Adds a default value to this query.
  ///
  /// - Parameter value: The default value for this query.
  /// - Returns: A ``DefaultQuery``.
  public func defaultValue(
    _ value: @autoclosure @escaping @Sendable () -> Value
  ) -> DefaultQuery<Self> where State == QueryState<Value?, Value> {
    DefaultQuery(_defaultValue: value, query: self)
  }
}

public struct DefaultQuery<Query: QueryRequest>: QueryRequest {
  public typealias State = QueryState<Query.Value, Query.Value>

  let _defaultValue: @Sendable () -> Query.Value
  public let query: Query

  public var defaultValue: Query.Value {
    self._defaultValue()
  }

  public var path: QueryPath {
    self.query.path
  }

  public func setup(context: inout QueryContext) {
    self.query.setup(context: &context)
  }

  public func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await self.query.fetch(in: context, with: continuation)
  }
}
