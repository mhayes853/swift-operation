// MARK: - MutationValue

/// The data type returned from a ``MutationRequest``.
///
/// You do not construct this type, ``MutationRequest`` constructs  for you.
public struct MutationValue<ReturnValue: Sendable>: Sendable {
  /// The value returned from ``MutationRequest/mutate(with:in:with:)``.
  public let returnValue: ReturnValue
}

// MARK: - MutationRequest

/// A protocol describing a mutation.
///
/// Mutations are used when mutating remote data in your application. For instance, this may be
/// submitting a POST request to an HTTP API based on user input from a form.
///
/// `MutationRequest` inherits from ``QueryRequest``, and adds 2 additional requirements:
/// 1. An ``Arguments`` associated type for defining the input to a mutation.
/// 2. A ``mutate(with:in:with:)`` method to perform the mutation logic.
///
/// ```swift
/// extension Post {
///   static let likeMutation = LikeMutation()
///
///   struct LikeMutation: MutationRequest, Hashable {
///     typealias Value = Void
///
///     func mutate(
///       with arguments: Post.ID,
///       in context: OperationContext,
///       with continuation: OperationContinuation<Void>
///     ) async throws {
///       // POST to the API to like the post...
///     }
///   }
/// }
/// ```
///
/// Mutations are called with arguments directly. For instance, when you have a ``OperationStore``
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
/// > Notice: A purple runtime warning and test failure will be issued in Xcode if you call
/// > `retryLatest` without ever having called `mutate` first. Additionally, your mutation will
/// > throw an error.
public protocol MutationRequest<Arguments, ReturnValue>: OperationRequest, Sendable
where Value == MutationValue<ReturnValue>, State == MutationState<Arguments, ReturnValue> {
  /// The data type of the arguments to submit to the mutation.
  associatedtype Arguments: Sendable

  /// The data type of the returned from the mutation.
  associatedtype ReturnValue: Sendable

  /// Mutates with the specified arguments.
  ///
  /// - Parameters:
  ///   - arguments: An instance of ``Arguments``.
  ///   - context: The ``OperationContext`` passed to this mutation.
  ///   - continuation: A ``OperationContinuation`` that allows you to yield values during the mutation. See <doc:MultistageQueries> for more.
  /// - Returns: The mutation value.
  func mutate(
    with arguments: Arguments,
    in context: OperationContext,
    with continuation: OperationContinuation<ReturnValue>
  ) async throws -> ReturnValue
}

// MARK: - Fetch

extension MutationRequest {
  public func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Value>
  ) async throws -> Value {
    guard let args = context.mutationArgs(as: Arguments.self) else {
      throw MutationNoArgumentsError()
    }
    let value = try await self.mutate(
      with: args,
      in: context,
      with: OperationContinuation { result, context in
        continuation.yield(with: result.map { MutationValue(returnValue: $0) }, using: context)
      }
    )
    return MutationValue(returnValue: value)
  }
}

private struct MutationNoArgumentsError: Error {}

// MARK: - Void Mutate

extension MutationRequest where Arguments == Void {
  /// Mutates with no arguments.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` passed to this mutation.
  ///   - continuation: A ``OperationContinuation`` that allows you to yield values during the mutation. See <doc:MultistageQueries> for more.
  /// - Returns: The mutation value.
  public func mutate(
    in context: OperationContext,
    with continuation: OperationContinuation<ReturnValue>
  ) async throws -> ReturnValue {
    try await self.mutate(with: (), in: context, with: continuation)
  }
}
