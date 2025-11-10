// MARK: - OperationModifier

/// A protocol for defining reusable and composable logic for operations.
///
/// The library comes with many built-in modifiers that you can use to customize the logic and
/// behavior of an operation. For instance, ``OperationRequest/retry(limit:)`` adds retry logic
/// with backoff to any operation regardless of whether or not its a ``QueryRequest``,
/// ``MutationRequest``, or ``PaginatedRequest``.
///
/// To create your own modifier, create a data type that conforms to this protocol. We'll create a
/// simple modifier that adds artificial delay to any operation.
///
/// ```swift
/// struct DelayModifier<Operation: OperationRequest>: OperationModifier {
///   let seconds: TimeInterval
///
///   func run(
///     isolation: isolated (any Actor)?,
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
/// Then, write an extension method on ``OperationRequest`` that makes consuming your modifier
/// easy for callers constructing an operation.
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
/// > type instead of `some OperationRequest<Value>`. The former style ensures that concrete operation types
/// > can use our modifier whilst still being recognized as conformances to their respective base
/// > operation type (eg. ``QueryRequest``) by the compiler.
/// > ```swift
/// > @QueryRequest
/// > func myQuery() async throws -> Value {
/// >   // ...
/// > }
/// >
/// > extension OperationRequest {
/// >   // ❌ Don't return 'some OperationRequest<Value>'.
/// >   func delay(
/// >     for seconds: TimeInterval
/// >   ) -> some OperationRequest<Value> {
/// >     self.modifier(DelayModifier(seconds: seconds))
/// >   }
/// > }
/// >
/// > // ❌ QueryRequest conformance is lost due to opaque type.
/// > let query = $myQuery.delay(for: 3)
/// > ```
public protocol OperationModifier<Value, Failure> {
  /// The underlying ``OperationRequest`` type.
  associatedtype Operation: OperationRequest

  /// The value returned from an operation run with this modifier.
  associatedtype Value

  /// The error thrown from an operation run with this modifier.
  associatedtype Failure: Error

  /// Sets up the initial ``OperationContext`` for the specified operation.
  ///
  /// This method is called a single time when an ``OperationStore`` is initialized with the
  /// specified operation.
  ///
  /// Make sure to call ``OperationRequest/setup(context:)-9fupm`` on `operation` in order to apply the
  /// functionallity required by other modifiers that are attached to the specified operation.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` to setup.
  ///   - operation: The specified operation this modifier must setup.
  func setup(context: inout OperationContext, using operation: Operation)

  /// Runs the specified operation with this modifier's behavior attached.
  ///
  /// - Parameters:
  ///   - isolation: The current isolation context of the `operation` run.
  ///   - context: The ``OperationContext`` passed to this modifier.
  ///   - operation: The specified operation to run.
  ///   - continuation: An ``OperationContinuation`` allowing you to yield multiple values from your
  ///     modifier. See <doc:MultistageOperations> for more.
  /// - Returns: The operation value.
  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Value, Failure>
  ) async throws(Failure) -> Value
}

extension OperationModifier {
  public func setup(context: inout OperationContext, using operation: Operation) {
    operation.setup(context: &context)
  }
}

// MARK: - ContextOperationModifier

public protocol _ContextUpdatingOperationModifier: OperationModifier, Sendable {
  func setup(context: inout OperationContext)
}

extension _ContextUpdatingOperationModifier {
  public func setup(context: inout OperationContext, using operation: Operation) {
    self.setup(context: &context)
    operation.setup(context: &context)
  }

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

/// An operation with an ``OperationModifier`` attached to it.
///
/// You create instances of this type through ``OperationRequest/modifier(_:)``.
public struct ModifiedOperation<
  Operation: OperationRequest,
  Modifier: OperationModifier
>: OperationRequest where Modifier.Operation == Operation {
  public typealias Value = Modifier.Value

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
    with continuation: OperationContinuation<Modifier.Value, Modifier.Failure>
  ) async throws(Modifier.Failure) -> Modifier.Value {
    try await self.modifier.run(
      isolation: isolation,
      in: context,
      using: self.operation,
      with: continuation
    )
  }
}

extension ModifiedOperation: StatefulOperationRequest
where
  Modifier.Operation: StatefulOperationRequest,
  Operation.Value == Modifier.Value,
  Operation.Failure == Modifier.Failure
{
  public typealias State = Operation.State

  @inlinable
  public var path: OperationPath {
    self.operation.path
  }
}

extension ModifiedOperation: Sendable where Operation: Sendable, Modifier: Sendable {}
