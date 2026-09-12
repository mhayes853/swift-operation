import Clocks
import CustomDump
import Operation
import Testing

@Suite("TimeoutOperation tests")
struct TimeoutOperationTests {
  @Test("Returns When The Operation Finishes Before The Timeout")
  func returnsWhenTheOperationFinishesBeforeTheTimeout() async throws {
    let clock = TestClock()
    let operation =
      $successfulTimeoutOperation
      .timeout(after: .seconds(5))
      .delayer(.clock(clock))

    let value = try await OperationRunner(operation: operation).run()

    expectNoDifference(value, 42)
    try await clock.checkSuspension()
  }

  @Test("Throws The Default Timeout Error")
  func throwsTheDefaultTimeoutError() async {
    let clock = TestClock()
    let (starts, startContinuation) = AsyncStream<Void>.makeStream()
    let operation = $endlessTimeoutOperation(startContinuation: startContinuation)
      .timeout(after: .seconds(5))
      .delayer(.clock(clock))
    let task = Task { try await OperationRunner(operation: operation).run() }
    var startIterator = starts.makeAsyncIterator()
    _ = await startIterator.next()

    await clock.advance(by: .seconds(5))

    await #expect(throws: OperationTimeoutError(duration: .seconds(5))) {
      try await task.value
    }
  }

  @Test("Throws The Supplied Typed Failure")
  func throwsTheSuppliedTypedFailure() async {
    let clock = TestClock()
    let (starts, startContinuation) = AsyncStream<Void>.makeStream()
    let operation = $typedEndlessTimeoutOperation(startContinuation: startContinuation)
      .timeout(after: .seconds(5), throwing: TestFailure.timedOut)
      .delayer(.clock(clock))
    let task = Task { try await OperationRunner(operation: operation).run() }
    var startIterator = starts.makeAsyncIterator()
    _ = await startIterator.next()

    await clock.advance(by: .seconds(5))

    await #expect(throws: TestFailure.timedOut) {
      try await task.value
    }
  }

  @Test("Preserves An Operation Failure Before The Timeout")
  func preservesAnOperationFailureBeforeTheTimeout() async {
    let clock = TestClock()
    let operation =
      $failingTimeoutOperation
      .timeout(after: .seconds(5), throwing: TestFailure.timedOut)
      .delayer(.clock(clock))

    await #expect(throws: TestFailure.operation) {
      try await OperationRunner(operation: operation).run()
    }
  }

  @Test("A Nonpositive Duration Times Out Without Starting The Operation")
  func aNonpositiveDurationTimesOutWithoutStartingTheOperation() async {
    let recorder = InvocationRecorder()
    let operation = $recordingTimeoutOperation(recorder: recorder)
      .timeout(after: .zero, throwing: TestFailure.timedOut)

    await #expect(throws: TestFailure.timedOut) {
      try await OperationRunner(operation: operation).run()
    }
    let invocationCount = await recorder.invocationCount
    expectNoDifference(invocationCount, 0)
  }

  @Test("Caller Cancellation Uses The Typed Operation Failure")
  func callerCancellationUsesTheTypedOperationFailure() async {
    let clock = TestClock()
    let (starts, startContinuation) = AsyncStream<Void>.makeStream()
    let operation = $typedEndlessTimeoutOperation(startContinuation: startContinuation)
      .timeout(after: .seconds(5), throwing: TestFailure.timedOut)
      .delayer(.clock(clock))
    let task = Task { try await OperationRunner(operation: operation).run() }
    var startIterator = starts.makeAsyncIterator()
    _ = await startIterator.next()

    task.cancel()

    await #expect(throws: TestFailure.cancelled) {
      try await task.value
    }
  }

  @Test("Caller Cancellation Propagates A Cancellation Error")
  func callerCancellationPropagatesACancellationError() async {
    let clock = TestClock()
    let (starts, startContinuation) = AsyncStream<Void>.makeStream()
    let operation = $endlessTimeoutOperation(startContinuation: startContinuation)
      .timeout(after: .seconds(5))
      .delayer(.clock(clock))
    let task = Task { try await OperationRunner(operation: operation).run() }
    var startIterator = starts.makeAsyncIterator()
    _ = await startIterator.next()

    task.cancel()

    await #expect(throws: CancellationError.self) {
      try await task.value
    }
  }

  @Test("Preserves Stateful Operation Conformance For Typed Failures")
  func preservesStatefulOperationConformanceForTypedFailures() async throws {
    let query =
      $typedFailureTimeoutQuery
      .timeout(after: .seconds(5), throwing: TestFailure.timedOut)
    let store = OperationStore.detached(query: query, initialValue: nil)

    let value = try await store.fetch()

    expectNoDifference(value, 42)
  }

  @Test("A Timeout Outside Retry Limits The Entire Retry Sequence")
  func aTimeoutOutsideRetryLimitsTheEntireRetrySequence() async {
    let clock = TestClock()
    let recorder = InvocationRecorder()
    let (attempts, attemptContinuation) = AsyncStream<Int>.makeStream()
    let operation = $retryFailingTimeoutOperation(
      recorder: recorder,
      attemptContinuation: attemptContinuation
    )
    .retry(limit: 1)
    .backoff(.constant(.seconds(10)))
    .timeout(
      after: OperationDuration.seconds(5),
      throwing: TestFailure.timedOut
    )
    .delayer(.clock(clock))
    let task = Task { try await OperationRunner(operation: operation).run() }
    var attemptIterator = attempts.makeAsyncIterator()
    _ = await attemptIterator.next()

    await clock.advance(by: .seconds(5))

    await #expect(throws: TestFailure.timedOut) {
      try await task.value
    }
    let invocationCount = await recorder.invocationCount
    expectNoDifference(invocationCount, 1)
  }

  @Test("A Timeout Inside Retry Applies To Each Attempt")
  func aTimeoutInsideRetryAppliesToEachAttempt() async {
    let clock = TestClock()
    let recorder = InvocationRecorder()
    let (attempts, attemptContinuation) = AsyncStream<Int>.makeStream()
    let operation = $retryEndlessTimeoutOperation(
      recorder: recorder,
      attemptContinuation: attemptContinuation
    )
    .timeout(after: .seconds(5), throwing: TestFailure.timedOut)
    .retry(limit: 1)
    .backoff(.constant(.seconds(1)))
    .delayer(.clock(clock))
    let task = Task { try await OperationRunner(operation: operation).run() }
    var attemptIterator = attempts.makeAsyncIterator()
    _ = await attemptIterator.next()

    await clock.advance(by: .seconds(5))
    await clock.advance(by: .seconds(1))
    _ = await attemptIterator.next()
    await clock.advance(by: .seconds(5))

    await #expect(throws: TestFailure.timedOut) {
      try await task.value
    }
    let invocationCount = await recorder.invocationCount
    expectNoDifference(invocationCount, 2)
  }
}

@OperationRequest
private func successfulTimeoutOperation() async throws -> Int {
  42
}

@OperationRequest
private func endlessTimeoutOperation(
  startContinuation: AsyncStream<Void>.Continuation
) async throws -> Int {
  startContinuation.yield()
  try await Task.sleep(nanoseconds: .max)
  return 42
}

@OperationRequest
private func typedEndlessTimeoutOperation(
  startContinuation: AsyncStream<Void>.Continuation
) async throws(TestFailure) -> Int {
  startContinuation.yield()
  do {
    try await Task.sleep(nanoseconds: .max)
    return 42
  } catch {
    throw TestFailure.cancelled
  }
}

@OperationRequest
private func failingTimeoutOperation() throws(TestFailure) -> Int {
  throw TestFailure.operation
}

@OperationRequest
private func recordingTimeoutOperation(
  recorder: InvocationRecorder
) async throws(TestFailure) -> Int {
  await recorder.recordInvocation()
  return 42
}

@OperationRequest
private func retryFailingTimeoutOperation(
  recorder: InvocationRecorder,
  attemptContinuation: AsyncStream<Int>.Continuation
) async throws(TestFailure) -> Int {
  let attempt = await recorder.recordInvocation()
  attemptContinuation.yield(attempt)
  throw TestFailure.operation
}

@OperationRequest
private func retryEndlessTimeoutOperation(
  recorder: InvocationRecorder,
  attemptContinuation: AsyncStream<Int>.Continuation
) async throws(TestFailure) -> Int {
  let attempt = await recorder.recordInvocation()
  attemptContinuation.yield(attempt)
  do {
    try await Task.sleep(nanoseconds: .max)
    return 42
  } catch {
    throw TestFailure.cancelled
  }
}

@QueryRequest
private func typedFailureTimeoutQuery() async throws(TestFailure) -> Int {
  42
}

private enum TestFailure: Error, Equatable, Sendable {
  case cancelled
  case operation
  case timedOut
}

private actor InvocationRecorder {
  private(set) var invocationCount = 0

  @discardableResult
  func recordInvocation() -> Int {
    self.invocationCount += 1
    return self.invocationCount
  }
}
