// MARK: - OperationModifier

/// A protocol for defining reusable and composable logic for your queries.
///
/// The library comes with many built-in modifiers that you can use to customize the logic and
/// behavior of your queries. For instance, ``QueryRequest/retry(limit:)`` adds
/// retry logic to your queries.
///
/// To create your own modifier, create a data type that conforms to this protocol. We'll create a
/// simple modifier that adds artificial delay to any query.
///
/// ```swift
/// struct DelayModifier<Operation: OperationRequest>: OperationModifier {
///   let seconds: TimeInterval
///
///   func fetch(
///     in context: OperationContext,
///     using query: Query,
///     with continuation: OperationContinuation<Query.Value>
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
/// extension OperationRequest {
///   func delay(
///     for seconds: TimeInterval
///   ) -> ModifiedOperation<Self, DelayModifier<Self>> {
///     self.modifier(DelayModifier(seconds: seconds))
///   }
/// }
/// ```
///
/// > Note: It's essential that we have `ModifiedOperation<Self, DelayModifier<Self>>` as the return
/// > type instead of `some QueryRequest<Value, State>`. The former style ensures that infinite
/// > queries and mutations can use our modifier whilst still being recognized as their respective
/// > ``PaginatedRequest`` or ``MutationRequest`` conformances by the compiler.
public protocol OperationModifier<Operation> {
  /// The underlying ``OperationRequest`` type.
  associatedtype Operation: OperationRequest

  /// Sets up the initial ``OperationContext`` for the specified operation.
  ///
  /// This method is called a single time when a ``OperationStore`` is initialized with your operation.
  ///
  /// Make sure to call ``OperationRequest/setup`` on `operation` in order to apply the
  /// functionallity required by other modifiers that are attached to this operation.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` to setup.
  ///   - operation: The underlying operation for this modifier.
  func setup(context: inout OperationContext, using operation: Operation)

  /// Fetches the data for the specified operation.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` passed to this modifier.
  ///   - operation: The underlying operation to fetch data from.
  ///   - continuation: A ``OperationContinuation`` allowing you to yield multiple values from your
  ///     modifier. See <doc:MultistageQueries> for more.
  /// - Returns: The operation value.
  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value
}

extension OperationModifier {
  public func setup(context: inout OperationContext, using query: Operation) {
    query.setup(context: &context)
  }
}

// MARK: - ContextOperationModifier

public protocol _ContextUpdatingOperationModifier: OperationModifier, Sendable {
  func setup(context: inout OperationContext)
}

extension _ContextUpdatingOperationModifier {
  @inlinable
  public func setup(context: inout OperationContext, using query: Operation) {
    self.setup(context: &context)
    query.setup(context: &context)
  }

  @inlinable
  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    try await operation.run(isolation: isolation, in: context, with: continuation)
  }
}

// MARK: - ModifiedOperation

extension OperationRequest {
  /// Applies an ``OperationModifier`` to your operation.
  ///
  /// - Parameter modifier: The modifier to apply.
  /// - Returns: A ``ModifiedOperation``.
  public func modifier<Modifier: OperationModifier>(
    _ modifier: Modifier
  ) -> ModifiedOperation<Self, Modifier> {
    ModifiedOperation(operation: self, modifier: modifier)
  }
}

/// An operation with a ``OperationModifier`` attached to it.
///
/// You created instances of this type through ``OperationRequest/modifier(_:)``.
public struct ModifiedOperation<
  Operation: OperationRequest,
  Modifier: OperationModifier
>: OperationRequest where Modifier.Operation == Operation {
  public typealias Value = Operation.Value

  /// The base ``OperationRequest``.
  public let operation: Operation

  /// The ``OperationModifier`` attached to ``operation``.
  public let modifier: Modifier

  @inlinable
  public var _debugTypeName: String {
    self.operation._debugTypeName
  }

  @inlinable
  public func setup(context: inout OperationContext) {
    self.modifier.setup(context: &context, using: self.operation)
  }

  @inlinable
  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    try await self.modifier.run(
      isolation: isolation,
      in: context,
      using: self.operation,
      with: continuation
    )
  }
}

extension ModifiedOperation: StatefulOperationRequest
where Modifier.Operation: StatefulOperationRequest {
  public typealias State = Operation.State

  @inlinable
  public var path: OperationPath {
    self.operation.path
  }
}

extension ModifiedOperation: Sendable where Operation: Sendable, Modifier: Sendable {}
