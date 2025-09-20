// MARK: - QueryRequest

/// A protocol for describing an operation that fetches data in its entirety.
///
/// ```swift
/// struct User: Sendable, Identifiable {
///   let id: Int
/// }
///
/// extension User {
///   static func query(
///     for id: Int
///   ) -> some QueryRequest<Self, any Error> {
///     Query(userId: id)
///   }
///
///   struct Query: QueryRequest, Hashable {
///     let userId: Int
///
///     func fetch(
///       isolation: isolated (any Actor)?,
///       in context: OperationContext,
///       with continuation: OperationContinuation<User, any Error>
///     ) async throws -> User {
///       // Fetch the user...
///     }
///   }
/// }
/// ```
public protocol QueryRequest<FetchValue, FetchFailure>: StatefulOperationRequest
where
  Self.FetchValue == Value,
  Self.FetchFailure == Failure,
  State == QueryState<FetchValue, FetchFailure>
{
  associatedtype FetchValue: Sendable
  associatedtype FetchFailure: Error

  /// Fetches the data for your query.
  ///
  /// - Parameters:
  ///   - context: A ``OperationContext`` that is passed to your query.
  ///   - continuation: A ``OperationContinuation`` that allows you to yield values while you're
  ///   fetching data. See <doc:MultistageOperations> for more.
  /// - Returns: The fetched value from your query.
  func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<FetchValue, FetchFailure>
  ) async throws(FetchFailure) -> FetchValue
}

// MARK: - Fetch

extension QueryRequest {
  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<FetchValue, FetchFailure>
  ) async throws(FetchFailure) -> FetchValue {
    try await self.fetch(isolation: isolation, in: context, with: continuation)
  }
}
