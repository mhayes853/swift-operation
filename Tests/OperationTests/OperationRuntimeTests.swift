import CustomDump
import Operation
import Testing

@Suite("OperationRuntime tests")
struct OperationRuntimeTests {
  @Test("Runs An Operation Without A Decorator")
  func runsAnOperationWithoutADecorator() async {
    let runtime = OperationRuntime()
    let value = await runtime.run(InlineOperation { _ in 42 })
    expectNoDifference(value, 42)
  }

  @Test("Hands Its Context To Every Operation It Runs")
  func handsItsContextToEveryOperationItRuns() async {
    var context = OperationContext()
    context.operationMaxRetries = 7
    let runtime = OperationRuntime(context: context)
    let first = await runtime.run(InlineOperation { $0.operationMaxRetries })
    let second = await runtime.run(InlineOperation { $0.operationMaxRetries })
    expectNoDifference([first, second], [7, 7])
  }

  @Test("Applies Its Decorator To Every Operation It Runs")
  func appliesItsDecoratorToEveryOperationItRuns() async {
    let counter = RunCounter()
    let runtime = OperationRuntime(decorator: RetryingDecorator(limit: 3))
    await #expect(throws: SomeError.self) {
      try await runtime.run(counter.alwaysFailingOperation())
    }
    expectNoDifference(counter.count, 4)
  }

  @Test("Decorates Operations Of Differing Value And Failure Types")
  func decoratesOperationsOfDifferingValueAndFailureTypes() async {
    let runtime = OperationRuntime(decorator: RetryingDecorator(limit: 1))
    let number = await runtime.run(InlineOperation { _ in 1 })
    let text = await runtime.run(InlineOperation { _ in "blob" })
    expectNoDifference(number, 1)
    expectNoDifference(text, "blob")
  }

  @Test("An Operation's Own Retry Limit Takes Precedence Over The Runtime's")
  func anOperationsOwnRetryLimitTakesPrecedenceOverTheRuntimes() async {
    let counter = RunCounter()
    let runtime = OperationRuntime(decorator: RetryingDecorator(limit: 10))
    await #expect(throws: SomeError.self) {
      try await runtime.run(
        counter.alwaysFailingOperation()
          .retry(limit: 1)
          .backoff(.noBackoff)
          .delayer(.noDelay)
      )
    }
    expectNoDifference(counter.count, 2)
  }

  @Test("Yields Values Through The Continuation")
  func yieldsValuesThroughTheContinuation() async {
    let yielded = RecursiveLock([Int]())
    let runtime = OperationRuntime()
    let operation = InlineOperation<Int, Never> { _, continuation in
      continuation.yield(1)
      return 2
    }
    let value = await runtime.run(
      operation,
      with: OperationContinuation { result, _ in
        guard case .success(let next) = result else { return }
        yielded.withLock { $0.append(next) }
      }
    )
    expectNoDifference(value, 2)
    expectNoDifference(yielded.withLock { $0 }, [1])
  }

  @Test("Invokes Setup On The Decorated Operation")
  func invokesSetupOnTheDecoratedOperation() async {
    let runtime = OperationRuntime(decorator: RetryingDecorator(limit: 4))
    // `retry(limit:)` writes the limit into the context during setup, so an operation that reads
    // it back can only see 4 if the decorator's setup ran.
    let limit = await runtime.run(InlineOperation { $0.operationMaxRetries })
    expectNoDifference(limit, 4)
  }
}

// MARK: - Helpers

private struct SomeError: Equatable, Error {}

private struct RetryingDecorator: OperationDecorator {
  let limit: Int

  func decorate<Operation: OperationRequest>(
    _ operation: Operation
  ) -> any OperationRequest<Operation.Value, Operation.Failure> {
    operation.retry(limit: self.limit).backoff(.noBackoff).delayer(.noDelay)
  }
}

private final class RunCounter: Sendable {
  private let _count = RecursiveLock(0)

  var count: Int {
    self._count.withLock { $0 }
  }

  func alwaysFailingOperation() -> InlineOperation<Int, any Error> {
    InlineOperation("always failing") { _ in
      self._count.withLock { $0 += 1 }
      throw SomeError()
    }
  }
}
