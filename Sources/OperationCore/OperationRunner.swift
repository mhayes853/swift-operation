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
  /// Any ``OperationTransform``s in scope for the current task have their modifiers applied to
  /// the operation for this run, and ``OperationRequest/setup(context:)-8y79v`` is invoked on
  /// those modifiers with ``OperationContext/modifierSetupScope`` set to
  /// ``OperationContext/ModifierSetupScope/operationRun``. That pass stops at the underlying
  /// operation, which is only ever set up once, in ``init(operation:initialContext:)``. A
  /// transform's configuration is therefore written on top of the operation's own, and takes
  /// precedence over it.
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
    let transforms = operationTransforms
    guard !transforms.isEmpty else {
      return try await self.operation.run(isolation: isolation, in: context, with: continuation)
    }
    let transformed = self.operation.applying(transforms)
    var runContext = context
    runContext.modifierSetupScope = .operationRun
    transformed.setup(context: &runContext)
    return try await transformed.run(isolation: isolation, in: runContext, with: continuation)
  }
}

extension OperationRunner: Sendable where Operation: Sendable {}
