// MARK: - OperationContinuation

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
///     in context: OperationContext,
///     with continuation: OperationContinuation<QueryData>
///   ) async throws -> QueryData {
///     if let cachedData = context.cache[key] {
///       continuation.yield(cachedData)
///     }
///     let freshData = try await fetchFreshData()
///     context.cache[key] = freshData
///     return freshData
///   }
/// }
///
/// extension OperationContext {
///   var cache: Cache {
///     // ...
///   }
/// }
/// ```
///
/// > Note: Read the <doc:MultistageQueries> article to learn the use cases for yielding data and
/// > how most effectively yield data from your queries.
public struct OperationContinuation<Value, Failure: Error>: Sendable {
  private let onQueryResult: @Sendable (sending Result<Value, Failure>, OperationContext?) -> Void

  /// Creates a continuation.
  ///
  /// - Parameter onQueryResult: A function to handle yielded query results.
  public init(
    onQueryResult: @escaping @Sendable (sending Result<Value, Failure>, OperationContext?) -> Void
  ) {
    self.onQueryResult = onQueryResult
  }
}

// MARK: - Yielding

extension OperationContinuation {
  /// Yields a value from the query.
  ///
  /// - Parameters:
  ///   - value: The value to yield.
  ///   - context: The ``OperationContext`` to yield with.
  public func yield(_ value: sending Value, using context: OperationContext? = nil) {
    self.yield(with: .success(value), using: context)
  }

  /// Yields an error from the query.
  ///
  /// - Parameters:
  ///   - error: The error to yield.
  ///   - context: The ``OperationContext`` to yield with.
  public func yield(error: Failure, using context: OperationContext? = nil) {
    self.yield(with: .failure(error), using: context)
  }

  /// Yields a result from the query.
  ///
  /// - Parameters:
  ///   - result: The result to yield.
  ///   - context: The ``OperationContext`` to yield with.
  public func yield(
    with result: sending Result<Value, Failure>,
    using context: OperationContext? = nil
  ) {
    self.onQueryResult(result, context)
  }
}
