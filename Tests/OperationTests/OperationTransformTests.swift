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

  @Test("A Transform's Retry Limit Takes Precedence Over The Operation's Own")
  func aTransformsRetryLimitTakesPrecedenceOverTheOperationsOwn() async {
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
    expectNoDifference(counter.count, 11)
  }

  // MARK: - Operation Stores

  @Test("Applies A Transform's Retry Limit To A Store Created By An Operation Client")
  func appliesATransformsRetryLimitToAStoreCreatedByAnOperationClient() async {
    // The client applies its own `retry(limit:)` to every operation it creates a store for, which
    // sits closer to the operation than the transform's does.
    let counter = RunCounter()
    let store = OperationClient().store(for: FailingQuery(counter: counter))
    await withOperationTransform(RetryingTransform(limit: 10)) {
      _ = try? await store.fetch()
    }
    expectNoDifference(counter.count, 11)
  }

  @Test("Applies A Transform's Backoff Function To A Store Created By An Operation Client")
  func appliesATransformsBackoffFunctionToAStoreCreatedByAnOperationClient() async throws {
    let store = OperationClient().store(for: BackoffReportingQuery())
    let backoff = try await withOperationTransform(ConstantBackoffTransform(seconds: 99)) {
      try await store.fetch()
    }
    expectNoDifference(backoff, .seconds(99))
  }

  @Test("Does Not Break Deduplication When A Transform Is In Scope")
  func doesNotBreakDeduplicationWhenATransformIsInScope() async {
    // A store's modifiers are only ever set up once. Setting them up again on each run would mint
    // a second deduplication storage, leaving concurrent runs unable to see each other.
    let counter = RunCounter()
    let store = OperationClient().store(for: SlowQuery(counter: counter))
    await withOperationTransform(NoOpTransform()) {
      async let first: Void = { _ = try? await store.fetch() }()
      async let second: Void = { _ = try? await store.fetch() }()
      _ = await (first, second)
    }
    expectNoDifference(counter.count, 1)
  }

  @Test("Retries Within Deduplication When A Transform Raises The Retry Limit")
  func retriesWithinDeduplicationWhenATransformRaisesTheRetryLimit() async {
    // The transform steers the store's retryer rather than taking the loop, so the loop stays
    // inside `deduplicated()` and both callers share a single run's worth of attempts.
    let counter = RunCounter()
    let store = OperationClient().store(for: SlowFailingQuery(counter: counter))
    await withOperationTransform(RetryingTransform(limit: 2)) {
      async let first: Void = { _ = try? await store.fetch() }()
      async let second: Void = { _ = try? await store.fetch() }()
      _ = await (first, second)
    }
    expectNoDifference(counter.count, 3)
  }

  @Test("Does Not Duplicate Operation Controllers When A Transform Is In Scope")
  func doesNotDuplicateOperationControllersWhenATransformIsInScope() async throws {
    let store = OperationClient()
      .store(for: ControllerCountingQuery().controlled(by: NoOpController()))
    let outside = try await store.fetch()
    let inside = try await withOperationTransform(NoOpTransform()) { try await store.fetch() }
    expectNoDifference(inside, outside)
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

  @Test("Overrides The Transforms In Scope With A Single Transform")
  func overridesTheTransformsInScopeWithASingleTransform() async {
    let recorder = TagRecorder()
    await withOperationTransform(TaggingTransform(tag: "outer", recorder: recorder)) {
      await withOperationTransform(
        TaggingTransform(tag: "only", recorder: recorder),
        behavior: .override
      ) {
        _ = await #run(ConstantOperation(value: 1))
      }
    }
    expectNoDifference(recorder.tags, ["only"])
  }

  @Test("Appends A Sequence To The Transforms In Scope")
  func appendsASequenceToTheTransformsInScope() async {
    let recorder = TagRecorder()
    await withOperationTransform(TaggingTransform(tag: "outer", recorder: recorder)) {
      await withOperationTransforms(
        [
          TaggingTransform(tag: "first", recorder: recorder),
          TaggingTransform(tag: "second", recorder: recorder)
        ],
        behavior: .append
      ) {
        _ = await #run(ConstantOperation(value: 1))
      }
    }
    expectNoDifference(recorder.tags, ["outer", "first", "second"])
  }

  @Test("Hands A Single Transform The Operation's Own Type")
  func handsASingleTransformTheOperationsOwnType() async {
    let recorder = TagRecorder()
    await withOperationTransform(OperandNamingTransform(recorder: recorder)) {
      _ = await #run(ConstantOperation(value: 1))
    }
    expectNoDifference(recorder.tags.count, 1)
    expectNoDifference(recorder.tags[0].contains("AnyOperation"), false)
    expectNoDifference(recorder.tags[0].contains("ConstantOperation"), true)
  }

  @Test("Hands The Innermost Of Several Transforms The Operation's Own Type")
  func handsTheInnermostOfSeveralTransformsTheOperationsOwnType() async {
    let recorder = TagRecorder()
    let transforms: [any OperationTransform] = [
      TaggingTransform(tag: "outer", recorder: recorder),
      OperandNamingTransform(recorder: recorder)
    ]
    await withOperationTransforms(transforms) {
      _ = await #run(ConstantOperation(value: 1))
    }
    expectNoDifference(recorder.tags.last?.contains("AnyOperation"), false)
    expectNoDifference(recorder.tags.last?.contains("ConstantOperation"), true)
  }

  @Test("Applies Nothing When Given An Empty Sequence")
  func appliesNothingWhenGivenAnEmptySequence() async {
    let counter = RunCounter()
    await withOperationTransform(RetryingTransform(limit: 3)) {
      _ = await withOperationTransforms([]) {
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

private struct NoOpTransform: OperationTransform {
  func apply<Operation: OperationRequest>(
    to operation: Operation
  ) -> any OperationRequest<Operation.Value, Operation.Failure> {
    operation
  }
}

private struct ConstantBackoffTransform: OperationTransform {
  let seconds: Int

  func apply<Operation: OperationRequest>(
    to operation: Operation
  ) -> any OperationRequest<Operation.Value, Operation.Failure> {
    operation.backoff(.constant(.seconds(self.seconds)))
  }
}

private struct FailingQuery: QueryRequest, Sendable {
  let counter: RunCounter

  var path: OperationPath { OperationPath("transform-tests-failing-query") }

  func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Int, any Error>
  ) async throws -> Int {
    self.counter.increment()
    throw SomeError()
  }
}

private struct SlowQuery: QueryRequest, Sendable {
  let counter: RunCounter

  var path: OperationPath { OperationPath("transform-tests-slow-query") }

  func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Int, any Error>
  ) async throws -> Int {
    self.counter.increment()
    try await Task.sleep(for: .milliseconds(100))
    return 1
  }
}

private struct SlowFailingQuery: QueryRequest, Sendable {
  let counter: RunCounter

  var path: OperationPath { OperationPath("transform-tests-slow-failing-query") }

  func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Int, any Error>
  ) async throws -> Int {
    self.counter.increment()
    try await Task.sleep(for: .milliseconds(50))
    throw SomeError()
  }
}

private struct BackoffReportingQuery: QueryRequest, Sendable {
  var path: OperationPath { OperationPath("transform-tests-backoff-query") }

  func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<OperationDuration, any Error>
  ) async throws -> OperationDuration {
    context.operationBackoffFunction(1)
  }
}

private struct ControllerCountingQuery: QueryRequest, Sendable {
  var path: OperationPath { OperationPath("transform-tests-controller-query") }

  func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Int, any Error>
  ) async throws -> Int {
    context.operationControllers.count
  }
}

private struct NoOpController: OperationController {
  typealias State = QueryState<Int, any Error>

  func control(with controls: OperationControls<State>) -> OperationSubscription { .empty }
}

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

/// Records the type name of the operation it wraps, so that erasure of the operand is observable.
private struct OperandNamingTransform: OperationTransform {
  let recorder: TagRecorder

  func apply<Operation: OperationRequest>(
    to operation: Operation
  ) -> any OperationRequest<Operation.Value, Operation.Failure> {
    operation.modifier(OperandNamingModifier(recorder: self.recorder))
  }
}

private struct OperandNamingModifier<Operation: OperationRequest>: OperationModifier, Sendable {
  let recorder: TagRecorder

  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    self.recorder.append(operation._debugTypeName)
    return try await operation.run(isolation: isolation, in: context, with: continuation)
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
