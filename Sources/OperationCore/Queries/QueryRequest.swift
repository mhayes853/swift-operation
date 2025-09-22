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
///
/// Queries are the most basic stateful operation type in the sense that their primary purpose is
/// to just fetch data in its entirety with no strings attached. Ideally, they should not edit
/// data on any remote or external sources they utilize. ``MutationRequest`` is more suitable for
/// operations that edit data on remote and external sources.
///
/// Additionally, since queries fetch data in their entirety, you won't want to use them for cases
/// where you cannot load all the necessary data at once. ``PaginatedRequest`` is suited for
/// dealing with pagination in such cases.
public protocol QueryRequest<FetchValue, FetchFailure>: StatefulOperationRequest
where
  Self.FetchValue == Value,
  Self.FetchFailure == Failure,
  State == QueryState<FetchValue, FetchFailure>
{
  /// The value fetched from this query.
  associatedtype FetchValue: Sendable

  /// The error thrown from this query when fetching fails.
  associatedtype FetchFailure: Error

  /// Fetches the data for this query.
  ///
  /// - Parameters:
  ///   - isolation: The current isolation of the fetch.
  ///   - context: The ``OperationContext`` for this fetch.
  ///   - continuation: An ``OperationContinuation`` that allows you to yield intermittent values
  ///   while fetching. See <doc:MultistageOperations> for more.
  /// - Returns: The fetched value from this query.
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
