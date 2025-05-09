// MARK: - QueryModifier

/// A protocol for defining reusable and composable logic for your queries.
///
/// The library comes with many built-in modifiers that you can use to customize the logic and
/// behavior of your queries. For instance, ``QueryRequest/retry(limit:backoff:delayer:)`` adds
/// retry logic to your queries.
///
/// To create your own modifier, create a data type that conforms to this protocol. We'll create a
/// simple modifier that adds artificial delay to any query.
///
/// ```swift
/// struct DelayModifier<Query: QueryRequest>: QueryModifier {
///   let seconds: TimeInterval
///
///   func fetch(
///     in context: QueryContext,
///     using query: Query,
///     with continuation: QueryContinuation<Query.Value>
///   ) async throws -> Query.Value {
///     try await context.queryDelayer.delay(for: seconds)
///     return try await query.fetch(in: context, with: continuation)
///   }
/// }
/// ```
///
/// Then, write an extension property on ``QueryRequest`` that makes consuming your modifier easy.
///
/// ```swift
/// extension QueryRequest {
///   func delay(
///     for seconds: TimeInterval
///   ) -> ModifiedQuery<Self, DelayModifier<Self>> {
///     self.modifier(DelayModifier(seconds: seconds))
///   }
/// }
/// ```
///
/// > Note: It's essential that we have `ModifiedQuery<Self, DelayModifier<Self>>` as the return
/// > type instead of `some QueryRequest<Value, State>`. The former style ensures that infinite
/// > queries and mutations can use our modifier whilst still being recognized as their respective
/// > ``InfiniteQueryRequest`` or ``MutationRequest`` conformances by the compiler.
public protocol QueryModifier<Query>: Sendable {
  /// The underlying ``QueryRequest`` type.
  associatedtype Query: QueryRequest
  
  /// Sets up the initial ``QueryContext`` for the specified query.
  ///
  /// This method is called a single time when a ``QueryStore`` is initialized with your query.
  ///
  /// Make sure to call ``QueryRequest/setup(context:)-56d43`` on `query` in order to apply the
  /// functionallity required by other modifiers that are attached to this query.
  ///
  /// - Parameters:
  ///   - context: The ``QueryContext`` to setup.
  ///   - query: The underlying query for this modifier.
  func setup(context: inout QueryContext, using query: Query)
  
  /// Fetches the data for the specified query.
  ///
  /// - Parameters:
  ///   - context: The ``QueryContext`` passed to this modifier.
  ///   - query: The underlying query to fetch data from.
  ///   - continuation: A ``QueryContinuation`` allowing you to yield multiple values from your modifier. See <doc:MultistageQueries> for more.
  /// - Returns: The query value.
  func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value
}

extension QueryModifier {
  public func setup(context: inout QueryContext, using query: Query) {
    query.setup(context: &context)
  }
}

// MARK: - ModifiedQuery

extension QueryRequest {
  /// Applies a ``QueryModifier`` to your query.
  ///
  /// - Parameter modifier: The modifier to apply.
  /// - Returns: A ``ModifiedQuery``.
  public func modifier<Modifier: QueryModifier>(
    _ modifier: Modifier
  ) -> ModifiedQuery<Self, Modifier> {
    ModifiedQuery(query: self, modifier: modifier)
  }
}

/// A query with a ``QueryModifier`` attached to it.
///
/// You created instances of this type through ``QueryRequest/modifier(_:)``.
public struct ModifiedQuery<Query: QueryRequest, Modifier: QueryModifier>: QueryRequest
where Modifier.Query == Query {
  public typealias State = Query.State
  public typealias Value = Query.Value

  /// The base ``QueryRequest``.
  public let query: Query
  
  /// The ``QueryModifier`` attached to ``query``.
  public let modifier: Modifier

  public var path: QueryPath {
    self.query.path
  }

  public func setup(context: inout QueryContext) {
    self.modifier.setup(context: &context, using: query)
  }

  public func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await self.modifier.fetch(in: context, using: query, with: continuation)
  }
}
