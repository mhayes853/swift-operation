// MARK: - QueryContinuation

/// A data type for yielding intermittent results from a ``QueryRequest``.
///
/// Every query is passed a continuation in ``QueryRequest/fetch(in:with:)``, and you can use this
/// continuation to yield multiple data updates while fetching the primary data from your query.
///
/// ```swift
/// struct CacheableQuery: QueryRequest, Hashable {
///   let key: String
///
///   func fetch(
///     in context: QueryContext,
///     with continuation: QueryContinuation<QueryData>
///   ) async throws -> QueryData {
///      if let cachedData = Cache.shared[key] {
///      if let cachedData = context.cache[key] {
///       continuation.yield(cachedData)
///     }
///     let freshData = try await fetchFreshData()
///      Cache.shared[key] = freshData
///      context.cache[key] = freshData
///     return freshData
///   }
/// }
/// ```
///
/// > Note: Read the <doc:MultistageQueries> article to learn the use cases for yielding data and
/// > how most effectively yield data from your queries.
public struct QueryContinuation<Value: Sendable>: Sendable {
  private let onQueryResult: @Sendable (Result<Value, any Error>, QueryContext?) -> Void
  
  /// Creates a continuation.
  ///
  /// - Parameter onQueryResult: A function to handle yielded query results.
  public init(
    onQueryResult: @escaping @Sendable (Result<Value, any Error>, QueryContext?) -> Void
  ) {
    self.onQueryResult = onQueryResult
  }
}

// MARK: - Yielding

extension QueryContinuation {
  /// Yields a value from the query.
  ///
  /// - Parameters:
  ///   - value: The value to yield.
  ///   - context: The ``QueryContext`` to yield with.
  public func yield(_ value: Value, using context: QueryContext? = nil) {
    self.yield(with: .success(value), using: context)
  }

  /// Yields an error from the query.
  ///
  /// - Parameters:
  ///   - error: The error to yield.
  ///   - context: The ``QueryContext`` to yield with.
  public func yield(error: any Error, using context: QueryContext? = nil) {
    self.yield(with: .failure(error), using: context)
  }

  /// Yields a result from the query.
  ///
  /// - Parameters:
  ///   - result: The result to yield.
  ///   - context: The ``QueryContext`` to yield with.
  public func yield(with result: Result<Value, any Error>, using context: QueryContext? = nil) {
    self.onQueryResult(result, context)
  }
}
