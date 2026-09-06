import CustomDump
import Operation
import Testing

@Suite("OperationTransform tests")
struct OperationTransformTests {
  @Test("Does Not Apply A Transform When None Is In Scope")
  func doesNotApplyATransformWhenNoneIsInScope() async {
    let counter = RunCounter()
    await #expect(throws: SomeError.self) {
      try await #run(FailingOperation(counter: counter))
    }
    expectNoDifference(counter.count, 1)
  }

  @Test("Applies The Transform In Scope To A Run")
  func appliesTheTransformInScopeToARun() async {
    let counter = RunCounter()
    await withOperationTransform(RetryingTransform(limit: 3)) {
      await #expect(throws: SomeError.self) {
        try await #run(FailingOperation(counter: counter))
      }
    }
    expectNoDifference(counter.count, 4)
  }

  @Test("Does Not Apply The Transform After Its Scope Ends")
  func doesNotApplyTheTransformAfterItsScopeEnds() async {
    let counter = RunCounter()
    await withOperationTransform(RetryingTransform(limit: 3)) {}
    await #expect(throws: SomeError.self) {
      try await #run(FailingOperation(counter: counter))
    }
    expectNoDifference(counter.count, 1)
  }

  @Test("Applies The Transform To Operations Of Differing Value And Failure Types")
  func appliesTheTransformToOperationsOfDifferingValueAndFailureTypes() async {
    await withOperationTransform(RetryingTransform(limit: 1)) {
      let number = await #run(ConstantOperation(value: 1))
      let text = await #run(ConstantOperation(value: "blob"))
      expectNoDifference(number, 1)
      expectNoDifference(text, "blob")
    }
  }

  @Test("Sets Up The Transform's Modifiers")
  func setsUpTheTransformsModifiers() async {
    // `retry(limit:)` writes its limit into the context during setup, so the operation can only
    // read back 4 if the transform's modifiers were set up.
    let limit = await withOperationTransform(RetryingTransform(limit: 4)) {
      await #run(MaxRetriesOperation())
    }
    expectNoDifference(limit, 4)
  }

  @Test("An Operation's Own Retry Limit Takes Precedence Over The Transform's")
  func anOperationsOwnRetryLimitTakesPrecedenceOverTheTransforms() async {
    let counter = RunCounter()
    await withOperationTransform(RetryingTransform(limit: 10)) {
      await #expect(throws: SomeError.self) {
        try await #run(
          FailingOperation(counter: counter)
            .retry(limit: 1)
            .backoff(.noBackoff)
            .delayer(.noDelay)
        )
      }
    }
    expectNoDifference(counter.count, 2)
  }

  @Test("A Nested Transform Replaces The One Around It")
  func aNestedTransformReplacesTheOneAroundIt() async {
    let counter = RunCounter()
    await withOperationTransform(RetryingTransform(limit: 10)) {
      await withOperationTransform(RetryingTransform(limit: 1)) {
        await #expect(throws: SomeError.self) {
          try await #run(FailingOperation(counter: counter))
        }
      }
    }
    expectNoDifference(counter.count, 2)
  }

  @Test("Reaches Operations Run By Child Tasks")
  func reachesOperationsRunByChildTasks() async {
    let counter = RunCounter()
    await withOperationTransform(RetryingTransform(limit: 3)) {
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          _ = try? await #run(FailingOperation(counter: counter))
        }
        await group.waitForAll()
      }
    }
    expectNoDifference(counter.count, 4)
  }

  @Test("Yields Values Through The Continuation Under A Transform")
  func yieldsValuesThroughTheContinuationUnderATransform() async {
    let yielded = RecursiveLock([Int]())
    let value = await withOperationTransform(RetryingTransform(limit: 1)) {
      await #run(
        YieldingOperation(),
        context: OperationContext(),
        continuation: OperationContinuation { result, _ in
          guard case .success(let next) = result else { return }
          yielded.withLock { $0.append(next) }
        }
      )
    }
    expectNoDifference(value, 2)
    expectNoDifference(yielded.withLock { $0 }, [1])
  }

  @Test("Composes With The Transform Already In Scope When Asked To")
  func composesWithTheTransformAlreadyInScopeWhenAskedTo() async {
    let counter = RunCounter()
    await withOperationTransform(RetryingTransform(limit: 2)) {
      await withOperationTransform(ComposedTransform(base: currentOperationTransform)) {
        await #expect(throws: SomeError.self) {
          try await #run(FailingOperation(counter: counter))
        }
      }
    }
    expectNoDifference(counter.count, 3)
  }
}

// MARK: - Helpers

private struct SomeError: Equatable, Error {}

private struct RetryingTransform: OperationTransform {
  let limit: Int

  func apply<Operation: OperationRequest>(
    to operation: Operation
  ) -> any OperationRequest<Operation.Value, Operation.Failure> {
    operation.retry(limit: self.limit).backoff(.noBackoff).delayer(.noDelay)
  }
}

/// A transform that adds nothing of its own, so that what reaches the operation is whatever the
/// transform it was composed with contributes.
private struct ComposedTransform: OperationTransform {
  let base: (any OperationTransform)?

  func apply<Operation: OperationRequest>(
    to operation: Operation
  ) -> any OperationRequest<Operation.Value, Operation.Failure> {
    self.base?.apply(to: operation) ?? operation
  }
}

private final class RunCounter: Sendable {
  private let _count = RecursiveLock(0)

  var count: Int {
    self._count.withLock { $0 }
  }

  func increment() {
    self._count.withLock { $0 += 1 }
  }
}

private struct FailingOperation: OperationRequest, Sendable {
  let counter: RunCounter

  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Int, any Error>
  ) async throws -> Int {
    self.counter.increment()
    throw SomeError()
  }
}

private struct ConstantOperation<Value: Sendable>: OperationRequest, Sendable {
  let value: Value

  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Value, Never>
  ) async throws(Never) -> Value {
    self.value
  }
}

private struct MaxRetriesOperation: OperationRequest, Sendable {
  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Int, Never>
  ) async throws(Never) -> Int {
    context.operationMaxRetries
  }
}

private struct YieldingOperation: OperationRequest, Sendable {
  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Int, Never>
  ) async throws(Never) -> Int {
    continuation.yield(1)
    return 2
  }
}
