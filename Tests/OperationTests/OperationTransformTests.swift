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

  @Test("A Nested Transform Composes With The One Around It")
  func aNestedTransformComposesWithTheOneAroundIt() async {
    let recorder = TagRecorder()
    await withOperationTransform(TaggingTransform(tag: "outer", recorder: recorder)) {
      await withOperationTransform(TaggingTransform(tag: "inner", recorder: recorder)) {
        _ = await #run(ConstantOperation(value: 1))
      }
    }
    expectNoDifference(recorder.tags, ["outer", "inner"])
  }

  @Test("Applies The Innermost Transform Closest To The Operation")
  func appliesTheInnermostTransformClosestToTheOperation() async {
    let recorder = TagRecorder()
    await withOperationTransforms([
      TaggingTransform(tag: "first", recorder: recorder),
      TaggingTransform(tag: "second", recorder: recorder)
    ]) {
      _ = await #run(ConstantOperation(value: 1))
    }
    // Modifiers run outermost first, so the last transform given is the one nearest the operation.
    expectNoDifference(recorder.tags, ["first", "second"])
  }

  @Test("Reports The Transforms In Scope, Outermost First")
  func reportsTheTransformsInScopeOutermostFirst() async {
    let recorder = TagRecorder()
    expectNoDifference(operationTransforms.count, 0)
    await withOperationTransform(TaggingTransform(tag: "outer", recorder: recorder)) {
      await withOperationTransform(TaggingTransform(tag: "inner", recorder: recorder)) {
        let tags = operationTransforms.compactMap { ($0 as? TaggingTransform)?.tag }
        expectNoDifference(tags, ["outer", "inner"])
      }
    }
    expectNoDifference(operationTransforms.count, 0)
  }

  @Test("Replaces The Transforms In Scope With An Explicit Sequence")
  func replacesTheTransformsInScopeWithAnExplicitSequence() async {
    let recorder = TagRecorder()
    await withOperationTransform(TaggingTransform(tag: "outer", recorder: recorder)) {
      await withOperationTransforms([TaggingTransform(tag: "only", recorder: recorder)]) {
        _ = await #run(ConstantOperation(value: 1))
      }
    }
    expectNoDifference(recorder.tags, ["only"])
  }

  @Test("Applies Nothing When Given An Empty Sequence")
  func appliesNothingWhenGivenAnEmptySequence() async {
    let counter = RunCounter()
    await withOperationTransform(RetryingTransform(limit: 3)) {
      await withOperationTransforms([]) {
        await #expect(throws: SomeError.self) {
          try await #run(FailingOperation(counter: counter))
        }
      }
    }
    expectNoDifference(counter.count, 1)
  }

  @Test("Carries The Transforms In Scope Across A Detached Task")
  func carriesTheTransformsInScopeAcrossADetachedTask() async {
    let counter = RunCounter()
    let carried = await withOperationTransform(RetryingTransform(limit: 3)) {
      operationTransforms
    }
    await Task.detached {
      await withOperationTransforms(carried) {
        _ = try? await #run(FailingOperation(counter: counter))
      }
    }
    .value
    expectNoDifference(counter.count, 4)
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

/// Records a tag when the operation it wraps runs, so that composition order is observable.
private struct TaggingTransform: OperationTransform {
  let tag: String
  let recorder: TagRecorder

  func apply<Operation: OperationRequest>(
    to operation: Operation
  ) -> any OperationRequest<Operation.Value, Operation.Failure> {
    operation.modifier(TaggingModifier(tag: self.tag, recorder: self.recorder))
  }
}

private struct TaggingModifier<Operation: OperationRequest>: OperationModifier, Sendable {
  let tag: String
  let recorder: TagRecorder

  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    self.recorder.append(self.tag)
    return try await operation.run(isolation: isolation, in: context, with: continuation)
  }
}

private final class TagRecorder: Sendable {
  private let _tags = RecursiveLock([String]())

  var tags: [String] {
    self._tags.withLock { $0 }
  }

  func append(_ tag: String) {
    self._tags.withLock { $0.append(tag) }
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
