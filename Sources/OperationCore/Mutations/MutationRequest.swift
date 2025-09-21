// MARK: - MutationValue

/// The data type returned from a ``MutationRequest``.
///
/// You do not construct this type, ``MutationRequest`` constructs  for you.
public struct MutationOperationValue<ReturnValue: Sendable>: Sendable {
  /// The value returned from ``MutationRequest/mutate(isolation:with:in:with:)``.
  public let returnValue: ReturnValue
}

// MARK: - MutationRequest

/// A protocol describing an operation that creates, deletes, or updates data asynchronously.
///
/// Mutations are used when mutating remote data in your application. For instance, this may be
/// submitting a POST request to an HTTP API based on user input from a form.
///
/// `MutationRequest` inherits from ``StatefulOperationRequest``, and adds 2 additional requirements:
/// 1. An ``Arguments`` associated type for defining the input to a mutation.
/// 2. A ``mutate(isolation:with:in:with:)`` method to perform the mutation logic.
///
/// ```swift
/// extension Post {
///   static let likeMutation = LikeMutation()
///
///   struct LikeMutation: MutationRequest, Hashable {
///     func mutate(
///       isolation: isolated (any Actor)?,
///       with arguments: Post.ID,
///       in context: OperationContext,
///       with continuation: OperationContinuation<Void, any Error>
///     ) async throws {
///       // POST to the API to like the post...
///     }
///   }
/// }
/// ```
///
/// Mutations are called with arguments directly. For instance, when you have an ``OperationStore``
/// that uses a mutation, you can invoke your mutation's logic via
/// ``OperationStore/mutate(with:using:handler:)``.
///
/// ```swift
/// let store = client.store(for: Post.likeMutation)
///
/// try await store.mutate(with: postId)
/// ```
///
/// You can also retry the mutation with most recently used set of arguments via
/// ``OperationStore/retryLatest(using:handler:)``.
///
/// ```swift
/// try await store.retryLatest()
/// ```
///
/// > Warning: Your app will crash if you call `retryLatest` without ever having called `mutate` first.
///
/// Avoid using mutations as only a means to fetch data. ``QueryRequest`` and ``PaginatedRequest``
/// are more suitable for cases where you need to only fetch remote and external data without
/// making edits to it. This is because a single mutation instance works with multiple sets of
/// arguments passed to ``mutate(isolation:with:in:with:)`` at a time whilst separate
/// `QueryRequest` and `PaginatedRequest` instances must be constructed for each set of
/// arguments. Due to this, ``OperationClient`` is able to distinguish between separate
/// `QueryRequest` and `PaginatedRequest` instances, whereas it cannot distinguish between 2 sets
/// of arguments passed to a mutation.
public protocol MutationRequest<Arguments, MutateValue, MutateFailure>: StatefulOperationRequest
where
  Value == MutationOperationValue<MutateValue>,
  State == MutationState<Arguments, MutateValue, MutateFailure>,
  Failure == MutateFailure
{
  /// The data type of the arguments to use for a mutation run.
  associatedtype Arguments: Sendable

  /// The data type of the returned from a mutation run.
  associatedtype MutateValue: Sendable

  /// The error type thrown when a mutation run fails.
  associatedtype MutateFailure: Error

  /// Mutates with the specified arguments.
  ///
  /// - Parameters:
  ///   - isolation: The current isolation of the mutation run.
  ///   - arguments: An instance of <doc:/documentation/OperationCore/MutationRequest/Arguments>.
  ///   - context: The ``OperationContext`` of this mutation run.
  ///   - continuation: An ``OperationContinuation`` that allows you to yield intermittent values
  ///   during the mutation run. See <doc:MultistageOperations> for more.
  /// - Returns: The mutation value.
  func mutate(
    isolation: isolated (any Actor)?,
    with arguments: Arguments,
    in context: OperationContext,
    with continuation: OperationContinuation<MutateValue, MutateFailure>
  ) async throws(MutateFailure) -> MutateValue
}

// MARK: - Fetch

extension MutationRequest {
  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<MutationOperationValue<MutateValue>, Failure>
  ) async throws(MutateFailure) -> MutationOperationValue<MutateValue> {
    let args = context.mutationArgs(as: Arguments.self)!
    let value = try await self.mutate(
      isolation: isolation,
      with: args,
      in: context,
      with: OperationContinuation { result, context in
        continuation.yield(
          with: result.map { MutationOperationValue(returnValue: $0) },
          using: context
        )
      }
    )
    return MutationOperationValue(returnValue: value)
  }
}

// MARK: - Void Mutate

extension MutationRequest where Arguments == Void {
  /// Mutates with no arguments.
  ///
  /// - Parameters:
  ///   - isolation: The current isolation of the mutation run.
  ///   - context: The ``OperationContext`` of this mutation run.
  ///   - continuation: An ``OperationContinuation`` that allows you to yield intermittent values
  ///   during the mutation run. See <doc:MultistageOperations> for more.
  /// - Returns: The mutation value.
  public func mutate(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<MutateValue, MutateFailure>
  ) async throws(MutateFailure) -> MutateValue {
    try await self.mutate(isolation: isolation, with: (), in: context, with: continuation)
  }
}
