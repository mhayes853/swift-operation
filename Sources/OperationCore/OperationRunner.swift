/// A simple runtime for an ``OperationRequest``.
///
/// ```swift
/// struct MyOperation: OperationRequest {
///   // ...
/// }
///
/// let runner = OperationRunner(operation: MyOperation())
/// let value = try await runner.run()
///
/// // ...
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
    try await self.operation.run(
      isolation: isolation,
      in: context ?? self.context,
      with: continuation
    )
  }
}

extension OperationRunner: Sendable where Operation: Sendable {}
