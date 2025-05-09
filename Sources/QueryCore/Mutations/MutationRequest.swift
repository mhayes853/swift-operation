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
///       in context: QueryContext,
///       with continuation: QueryContinuation<Void>
///     ) async throws {
///       // POST to the API to like the post...
///     }
///   }
/// }
/// ```
///
/// > Warning: You do not implement ``fetch(in:with:)``, instead `MutationRequest` implements that
/// > requirement for you.
///
/// Mutations are called with arguments directly. For instance, when you have a ``QueryStore``
/// that uses a mutation, you can invoke your mutation's logic via
/// ``QueryStore/mutate(with:using:handler:)``.
///
/// ```swift
/// let store = client.store(for: Post.likeMutation)
///
/// try await store.mutate(with: postId)
/// ```
///
/// You can also retry the mutation with most recently used set of arguments via
/// ``QueryStore/retryLatest(using:handler:)``.
///
/// ```swift
/// try await store.retryLatest()
/// ```
///
/// > Notice: A purple runtime warning and test failure will be issued in Xcode if you call
/// > `retryLatest` without ever having called `mutate` first. Additionally, your mutation will
/// > throw an error.
public protocol MutationRequest<Arguments, Value>: QueryRequest
where State == MutationState<Arguments, Value> {
  /// The data type of the arguments to submit to the mutation.
  associatedtype Arguments: Sendable
  
  /// Mutates with the specified arguments.
  ///
  /// - Parameters:
  ///   - arguments: An instance of ``Arguments``.
  ///   - context: The ``QueryContext`` passed to this mutation.
  ///   - continuation: A ``QueryContinuation`` that allows you to yield values during the mutation. See <doc:MultistageQueries> for more.
  /// - Returns: The mutation value.
  func mutate(
    with arguments: Arguments,
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value
}

// MARK: - Fetch

extension MutationRequest {
  public func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value {
    guard let args = context.mutationArgs(as: Arguments.self) else {
      throw MutationNoArgumentsError()
    }
    return try await self.mutate(with: args, in: context, with: continuation)
  }
}

private struct MutationNoArgumentsError: Error {}

// MARK: - Void Mutate

extension MutationRequest where Arguments == Void {
  /// Mutates with no arguments.
  ///
  /// - Parameters:
  ///   - context: The ``QueryContext`` passed to this mutation.
  ///   - continuation: A ``QueryContinuation`` that allows you to yield values during the mutation. See <doc:MultistageQueries> for more.
  /// - Returns: The mutation value.
  public func mutate(
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value {
    try await self.mutate(with: (), in: context, with: continuation)
  }
}
