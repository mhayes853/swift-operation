public struct OperationRunner<Operation: OperationRequest> {
  public var context: OperationContext
  private let operation: Operation

  public init(operation: Operation, initialContext: OperationContext = OperationContext()) {
    var context = initialContext
    operation.setup(context: &context)
    self.context = context
    self.operation = operation
  }

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
