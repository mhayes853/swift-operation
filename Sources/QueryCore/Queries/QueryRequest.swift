// MARK: - QueryRequest

/// A protocol for describing a query.
///
/// All queries in the library conform to this protocol, including ``InfiniteQueryRequest`` and
/// ``MutationRequest``. Queries have associated type requirements on the kind of data that they
/// must fetch, and type of its state that is tracked inside a ``QueryStore``. Additionally, there
/// are functional requirements for performing the fetching logic, uniquely identifying the query
/// though a ``QueryPath``, and setting up its initial ``QueryContext``.
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
///       in context: QueryContext,
///       with continuation: QueryContinuation<User>
///     ) async throws -> User {
///       // Fetch the user...
///     }
///   }
/// }
/// ```
///
/// You can also choose to specify a manual ``path-1limj`` implementation that uniquely identifies
/// your query. This way, you can use the pattern matching features of ``QueryClient`` for global
/// state management in your application.
///
/// ```swift
/// extension User {
///   // ...
///
///   struct Query: QueryRequest, Hashable {
///     var path: QueryPath { ["user", userId] }
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
/// You can also attach reusable logic to your query through the ``QueryModifier`` protocol. For
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
/// > Note: The default initializer of ``QueryClient`` will automatically apply the retry modifier
/// > to your queries when calling ``QueryClient/store(for:)-3sn51``.
/// >
/// > See <doc:QueryDefaults> to learn how to customize query defaults including default modifiers.
///
/// Generally, you do not call ``fetch(in:with:)`` directly. Rather, you interact with your query
/// through a ``QueryStore``. Stores manage the state (ie. Loading, Error, Success) of your query,
/// and you can access the store for your query by using a ``QueryClient``.
///
/// ```swift
/// // Share a single instance of the client throughout your entire app.
/// let client = QueryClient()
///
/// let store = client.store(for: User.query(for: 1))
///
/// let user = try await store.fetch()
/// print("User", user)
/// ```
///
/// The `QueryClient` holds all `QueryStore`s that your app creates, thus allowing you to access
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
///       in context: QueryContext,
///       with continuation: QueryContinuation<User>
///     ) async throws -> User {
///       if let client = context.queryClient {
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
/// ``QueryContinuation``. This is particularly useful if you want to yield locally persisted data
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
///       in context: QueryContext,
///       with continuation: QueryContinuation<User>
///     ) async throws -> User {
///       continuation.yield(try await Cache.shared.user(with: userId))
///       // Fetch remote user...
///     }
///   }
/// }
/// ```
///
/// > Note: See <doc:MultistageQueries> for a list of advanced use cases involving
/// > ``QueryContinuation``.
public protocol QueryRequest<Value, State>: QueryPathable, Sendable
where State.QueryValue == Value {
  /// The data type that your query fetches.
  associatedtype Value: Sendable

  /// The state type of your query.
  associatedtype State: QueryStateProtocol = QueryState<Value?, Value>

  var _debugTypeName: String { get }

  /// A ``QueryPath`` that uniquely identifies your query.
  ///
  /// If your query conforms to Hashable or Identifiable, then this requirement is implemented by
  /// default. However, if you want to take advantage of pattern matching, then you'll want to
  /// implement this requirement manually.
  ///
  /// See <doc:PatternMatchingAndStateManagement> for more.
  var path: QueryPath { get }

  /// Sets up the initial ``QueryContext`` that gets passed to ``fetch(in:with:)``.
  ///
  /// This method is called a single time when a ``QueryStore`` is initialized with your query.
  ///
  /// - Parameter context: The context to setup.
  func setup(context: inout QueryContext)

  /// Fetches the data for your query.
  ///
  /// - Parameters:
  ///   - context: A ``QueryContext`` that is passed to your query from a ``QueryStore``.
  ///   - continuation: A ``QueryContinuation`` that allows you to yield values while you're fetching data. See <doc:MultistageQueries> for more.
  /// - Returns: The fetched value from your query.
  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value
}

// MARK: - Setup

extension QueryRequest {
  public func setup(context: inout QueryContext) {
  }
}

// MARK: - Path Defaults

extension QueryRequest where Self: Hashable {
  public var path: QueryPath {
    QueryPath(self)
  }
}

extension QueryRequest where Self: Identifiable, ID: Sendable {
  public var path: QueryPath {
    QueryPath(self.id)
  }
}

// MARK: - Debug Type Name Default

extension QueryRequest {
  public var _debugTypeName: String { typeName(Self.self) }
}
