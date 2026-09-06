/// A simple runtime for an ``OperationRequest``.
///
/// You will primarily use this runtime through the `#run` macro, which constructs an
/// `OperationRunner` and invokes ``run(isolation:in:with:)`` for you.
///
/// ```swift
/// @OperationRequest
/// func myOperation() async throws -> Value {
///   // ...
/// }
///
/// let value = try await #run($myOperation)
///
/// // You can still construct a runner manually for advanced control.
/// let runner = OperationRunner(operation: $myOperation)
/// runner.context = OperationContext()
/// let valueWithCustomContext = try await runner.run()
/// ```
///
/// The runner makes sure to invoke ``OperationRequest/setup(context:)-8y79v`` once during
/// ``init(operation:initialContext:)``. You can also modify the ``OperationContext`` that gets
/// handed to each operation run by modifying the ``context`` property, or by passing a dedicated
/// context to ``run(isolation:in:with:)``.
public struct OperationRunner<Operation: OperationRequest> {
  /// The current ``OperationContext`` associated with the underlying operation.
  public var context: OperationContext

  private let operation: Operation

  /// Creates a runner.
  ///
  /// This initializer invokes ``OperationRequest/setup(context:)-8y79v`` on the specified
  /// `operation` with an an inout ``OperationContext`` reference based on `initialContext`.
  ///
  /// - Parameters:
  ///   - operation: The ``OperationRequest`` to run.
  ///   - initialContext: The initial ``OperationContext`` for the operation.
  public init(operation: Operation, initialContext: OperationContext = OperationContext()) {
    var context = initialContext
    operation.setup(context: &context)
    self.context = context
    self.operation = operation
  }

  /// Runs the underlying operation of this runner.
  ///
  /// If an ``OperationTransform`` is in scope for the current task, its modifiers are applied to
  /// the operation for this run, and ``OperationRequest/setup(context:)-8y79v`` is invoked on the
  /// result. Setup therefore reaches the underlying operation a second time in that case, on a
  /// context that already reflects it.
  ///
  /// - Parameters:
  ///   - isolation: The current actor-isolation of this operation run.
  ///   - context: The ``OperationContext`` to pass to the operation run. (Defaults to the
  ///   ``context`` instance property if nil).
  ///   - continuation: An ``OperationContinuation`` that allows you to yield data while the
  ///   underlying operation is still running. See <doc:MultistageOperations> for more.
  /// - Returns: The value returned from the underlying operation.
  public func run(
    isolation: isolated (any Actor)? = #isolation,
    in context: OperationContext? = nil,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure> =
      OperationContinuation { _, _ in }
  ) async throws(Operation.Failure) -> Operation.Value {
    let context = context ?? self.context
    guard let transform = currentOperationTransform else {
      return try await self.operation.run(
        isolation: isolation,
        in: context,
        with: continuation
      )
    }
    // The transform is applied here rather than in `init`, because it adds modifiers that need
    // setting up, and a modifier may carry per-instance identity that would differ between two
    // applications. `_RetryModifier` does: applying a transform once to set up and again to run
    // would leave the context holding a retryer id that no longer matches any modifier, and
    // retrying would silently stop happening.
    let transformed = transform.apply(to: self.operation)
    var transformedContext = context
    transformed.setup(context: &transformedContext)
    return try await transformed.run(
      isolation: isolation,
      in: transformedContext,
      with: continuation
    )
  }
}

extension OperationRunner: Sendable where Operation: Sendable {}
