// MARK: - OperationContinuation

/// A data type for yielding intermittent results from an ``OperationRequest``.
///
/// Every operation is passed a continuation in to its body, which can be used to yield data
/// updates while your operation is still running.
///
/// ```swift
/// @QueryRequest
/// func cacheableQuery(
///   key: String,
///   context: OperationContext,
///   continuation: OperationContinuation<QueryData, any Error>
/// ) async throws -> QueryData {
///   if let cachedData = context.cache[key] {
///     continuation.yield(cachedData)
///   }
///   let freshData = try await fetchFreshData()
///   context.cache[key] = freshData
///   return freshData
/// }
///
/// extension OperationContext {
///   @ContextEntry var cache = Cache.shared
/// }
/// ```
///
/// > Note: Read the <doc:MultistageOperations> article to learn the use cases for yielding
/// > intermittent data from your operations.
public struct OperationContinuation<Value, Failure: Error>: Sendable {
  private let onResult: @Sendable (sending Result<Value, Failure>, OperationContext?) -> Void

  /// Creates a continuation.
  ///
  /// - Parameter onResult: A function to handle yielded operation results.
  public init(
    onResult: @escaping @Sendable (sending Result<Value, Failure>, OperationContext?) -> Void
  ) {
    self.onResult = onResult
  }
}

// MARK: - Yielding

extension OperationContinuation {
  /// Yields a value from the operation.
  ///
  /// - Parameters:
  ///   - value: The value to yield.
  ///   - context: The ``OperationContext`` to yield with.
  public func yield(_ value: sending Value, using context: OperationContext? = nil) {
    self.yield(with: .success(value), using: context)
  }

  /// Yields an error from the operation.
  ///
  /// - Parameters:
  ///   - error: The error to yield.
  ///   - context: The ``OperationContext`` to yield with.
  public func yield(error: Failure, using context: OperationContext? = nil) {
    self.yield(with: .failure(error), using: context)
  }

  /// Yields a result from the operation.
  ///
  /// - Parameters:
  ///   - result: The result to yield.
  ///   - context: The ``OperationContext`` to yield with.
  public func yield(
    with result: sending Result<Value, Failure>,
    using context: OperationContext? = nil
  ) {
    self.onResult(result, context)
  }
}
