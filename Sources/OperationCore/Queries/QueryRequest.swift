// MARK: - QueryRequest

/// A protocol for describing a query.
///
/// All queries in the library conform to this protocol, including ``InfiniteQueryRequest`` and
/// ``MutationRequest``. Queries have associated type requirements on the kind of data that they
/// must fetch, and type of its state that is tracked inside a ``OperationStore``. Additionally, there
/// are functional requirements for performing the fetching logic, uniquely identifying the query
/// though a ``OperationPath``, and setting up its initial ``OperationContext``.
///
/// Generally, as long as your query conforms to Hashable or Identifiable, the only requirement
/// you need to implement yourself is ``fetch(in:with:)``.
///
/// ```swift
/// struct User: Sendable, Identifiable {
///   let id: Int
/// }
///
/// extension User {
///   static func query(
///     for id: Int
///   ) -> some QueryRequest<Self, Query.State> {
///     Query(userId: id)
///   }
///
///   struct Query: QueryRequest, Hashable {
///     let userId: Int
///
///     func fetch(
///       in context: OperationContext,
///       with continuation: OperationContinuation<User>
///     ) async throws -> User {
///       // Fetch the user...
///     }
///   }
/// }
/// ```
///
/// You can also choose to specify a manual ``path-5745r`` implementation that uniquely identifies
/// your query. This way, you can use the pattern matching features of ``OperationClient`` for global
/// state management in your application.
///
/// ```swift
/// extension User {
///   // ...
///
///   struct Query: QueryRequest, Hashable {
///     var path: OperationPath { ["user", userId] }
///
///     // ...
///   }
/// }
///
/// // Retrieves all instances of the user query stores
/// // that have been used in your app.
/// let store = client.stores(
///   matching: ["user"],
///   of: User.Query.State.self
/// )
/// ```
///
/// > Note: See <doc:PatternMatchingAndStateManagement> to learn more about global state
/// > management practices.
///
/// You can also attach reusable logic to your query through the ``OperationModifier`` protocol. For
/// instance, you can add retry logic to your query like so.
///
/// ```swift
/// extension User {
///   static func query(
///     for id: Int
///   ) -> some QueryRequest<Self, Query.State> {
///     Query(userId: id).retry(limit: 3)
///   }
///
///   // ...
/// }
/// ```
///
/// > Note: The default initializer of ``OperationClient`` will automatically apply the retry modifier
/// > to your queries when calling ``OperationClient/store(for:)-3sn51``.
/// >
/// > See <doc:QueryDefaults> to learn how to customize query defaults including default modifiers.
///
/// Generally, you do not call ``fetch(in:with:)`` directly. Rather, you interact with your query
/// through a ``OperationStore``. Stores manage the state (ie. Loading, Error, Success) of your query,
/// and you can access the store for your query by using a ``OperationClient``.
///
/// ```swift
/// // Share a single instance of the client throughout your entire app.
/// let client = OperationClient()
///
/// let store = client.store(for: User.query(for: 1))
///
/// let user = try await store.fetch()
/// print("User", user)
/// ```
///
/// The `OperationClient` holds all `OperationStore`s that your app creates, thus allowing you to access
/// them at a later time enabling global state management for your app. You can access the client
/// from within ``fetch(in:with:)`` like so:
///
/// ```swift
/// extension User {
///   // ...
///
///   struct Query: QueryRequest, Hashable {
///     let userId: Int
///
///     func fetch(
///       in context: OperationContext,
///       with continuation: OperationContinuation<User>
///     ) async throws -> User {
///       if let client = context.operationClient {
///         // ...
///       }
///       // ...
///     }
///   }
/// }
/// ```
///
/// > Note: See <doc:PatternMatchingAndStateManagement> to learn how to best use the client within
/// > a query.
///
/// You can also yield multiple updates while fetching the primary data from your query through
/// ``OperationContinuation``. This is particularly useful if you want to yield locally persisted data
/// whilst fetching remote data from your query. Your query will remain in a loading state until
/// you return the final result from ``fetch(in:with:)``.
///
/// ```swift
/// extension User {
///   // ...
///
///   struct Query: QueryRequest, Hashable {
///     let userId: Int
///
///     func fetch(
///       in context: OperationContext,
///       with continuation: OperationContinuation<User>
///     ) async throws -> User {
///       continuation.yield(try await Cache.shared.user(with: userId))
///       // Fetch remote user...
///     }
///   }
/// }
/// ```
///
/// > Note: See <doc:MultistageQueries> for a list of advanced use cases involving
/// > ``OperationContinuation``.
public protocol QueryRequest<ReturnValue>: OperationRequest, Sendable
where Self.ReturnValue == Value, State == QueryState<ReturnValue, any Error> {
  associatedtype ReturnValue: Sendable

  /// Fetches the data for your query.
  ///
  /// - Parameters:
  ///   - context: A ``OperationContext`` that is passed to your query.
  ///   - continuation: A ``OperationContinuation`` that allows you to yield values while you're
  ///   fetching data. See <doc:MultistageQueries> for more.
  /// - Returns: The fetched value from your query.
  func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<ReturnValue>
  ) async throws -> ReturnValue
}

// MARK: - Fetch

extension QueryRequest {
  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Value>
  ) async throws -> Value {
    try await self.fetch(isolation: isolation, in: context, with: continuation)
  }
}
