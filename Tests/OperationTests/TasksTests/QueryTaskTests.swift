import CustomDump
import Foundation
@_spi(Warnings) import Operation
@_spi(Warnings) import OperationTestHelpers
import Testing

func isRunningTestsFromXcode() -> Bool {
  ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

// TODO: - These tests seem to pass, even in Xcode, but the Xcode test runner exits with code 74 afterwards.

@Suite("QueryTask tests", .disabled(if: isRunningTestsFromXcode()))
struct QueryTaskTests {
  @Test("Task With Dependencies, Runs Dependent Tasks")
  func runsDependentTasks() async throws {
    let runCount = RecursiveLock(0)

    let task1 = QueryTask<Int>(context: QueryContext()) { _, _ in 40 }
    let task2 = QueryTask<Int>(context: QueryContext()) { _, _ in
      runCount.withLock { $0 += 1 }
      return 32
    }
    task1.schedule(after: task2)
    _ = try await task1.runIfNeeded()
    runCount.withLock { expectNoDifference($0, 1) }
  }

  @Test("Ignores Errors From Dependent Tasks")
  func ignoresErrorsFromDependentTasks() async throws {
    struct SomeError: Error {}

    let task1 = QueryTask<Int>(context: QueryContext()) { _, _ in 40 }
    let task2 = QueryTask<Int>(context: QueryContext()) { _, _ in throw SomeError() }
    task1.schedule(after: task2)
    await #expect(throws: Never.self) {
      _ = try await task1.runIfNeeded()
    }
  }

  @Test("Task Has Not Been Started By Default")
  func taskHasNotBeenStartedByDefault() async throws {
    let task = QueryTask<Int>(context: QueryContext()) { _, _ in 40 }
    expectNoDifference(task.hasStarted, false)
  }

  @Test("Task Has Been Started When Run Called")
  func taskHasBeenStartedWhenRunCalled() async throws {
    let task = QueryTask<Int>(context: QueryContext()) { _, _ in 40 }
    _ = try await task.runIfNeeded()
    expectNoDifference(task.hasStarted, true)
  }

  @Test("Task Has Been Started While Running")
  func taskHasBeenStartedWhileRunning() async throws {
    let (startStream, startContinuation) = AsyncStream<Void>.makeStream()
    var startIter = startStream.makeAsyncIterator()

    let task = QueryTask<Int>(context: QueryContext()) { _, _ in
      startContinuation.yield()
      try await Task.never()
      return 40
    }
    Task { try await task.runIfNeeded() }
    await startIter.next()
    expectNoDifference(task.hasStarted, true)
  }

  @Test("Cancel Query Task While Running, Throws Cancellation Error")
  func cancelQueryTaskThrowsCancellationError() async throws {
    let task = QueryTask<Void>(context: QueryContext()) { _, _ in
      withUnsafeCurrentTask { $0?.cancel() }
      try await Task.never()
    }
    let base = Task {
      do {
        try await task.runIfNeeded()
        return false
      } catch is CancellationError {
        return true
      }
    }
    let value = try await base.value
    expectNoDifference(value, true)
  }

  @Test("Cancel Query Task From Task, Throws Cancellation Error")
  func cancelQueryTaskFromTaskThrowsCancellationError() async throws {
    let task = QueryTask<Void>(context: QueryContext()) { _, _ in try await Task.never() }
    let base = Task {
      do {
        try await task.runIfNeeded()
        return false
      } catch is CancellationError {
        return true
      }
    }
    base.cancel()
    let value = try await base.value
    expectNoDifference(value, true)
  }

  @Test("Cancel Query Task Before Running, Throws Cancellation Error Immediately")
  func cancelQueryTaskBeforeRunningThrowsCancellationErrorImmediately() async throws {
    let task = QueryTask<Void>(context: QueryContext()) { _, _ in try await Task.never() }
    task.cancel()
    await #expect(throws: CancellationError.self) {
      try await task.runIfNeeded()
    }
  }

  @Test("Is Cancelled Is False By Default")
  func isCancelledIsFalseByDefault() {
    let task = QueryTask<Void>(context: QueryContext()) { _, _ in try await Task.never() }
    expectNoDifference(task.isCancelled, false)
  }

  @Test("Cancel, Is Cancelled")
  func cancelIsCancelled() {
    let task = QueryTask<Void>(context: QueryContext()) { _, _ in try await Task.never() }
    task.cancel()
    expectNoDifference(task.isCancelled, true)
  }

  @Test("Cancel From Regular Task, Is Cancelled")
  func cancelFromRegularTaskIsCancelled() async throws {
    let task = QueryTask<Void>(context: QueryContext()) { _, _ in try await Task.never() }
    let base = Task { try await task.runIfNeeded() }
    base.cancel()
    await #expect(throws: CancellationError.self) {
      try await base.value
    }
    expectNoDifference(task.isCancelled, true)
  }

  @Test("Cancel From Regular Task When Not Respecting Cancellation Error, Is Cancelled")
  func cancelFromRegularTaskWhenNotRespectingCancellationError() async throws {
    let task = QueryTask<Void>(context: QueryContext()) { _, _ in try? await Task.never() }
    let base = Task { try await task.runIfNeeded() }
    base.cancel()
    await #expect(throws: CancellationError.self) {
      try await base.value
    }
    expectNoDifference(task.isCancelled, true)
  }

  @Test("Cannot Be Cancelled After Finishing")
  func cannotBeCancelledAfterFinishing() async throws {
    let task = QueryTask<Int>(context: QueryContext()) { _, _ in 42 }
    _ = try await task.runIfNeeded()
    task.cancel()
    expectNoDifference(task.isCancelled, false)
  }

  @Test("Map Task Value")
  func mapTaskValue() async throws {
    let task = QueryTask<Int>(context: QueryContext()) { _, _ in 42 }
    let task2 = task.map { $0 * 2 }
    _ = try await task.runIfNeeded()
    let value = try await task2.runIfNeeded()
    expectNoDifference(value, 84)
  }

  @Test("Map Task Value With Different Types")
  func mapTaskValueWithDifferentTypes() async throws {
    let task = QueryTask<Int>(context: QueryContext()) { _, _ in 42 }
    let task2 = task.map { String($0) }
    _ = try await task.runIfNeeded()
    let value = try await task2.runIfNeeded()
    expectNoDifference(value, "42")
  }

  @Test("QueryTask Is Not Finished By Default")
  func queryTaskIsNotFinishedByDefault() async throws {
    let task = QueryTask<Int>(context: QueryContext()) { _, _ in 42 }
    expectNoDifference(task.isFinished, false)
  }

  @Test("QueryTask Is Not Finished When Loading")
  func queryTaskIsNotFinishedWhenLoading() async throws {
    let (startStream, startContinuation) = AsyncStream<Void>.makeStream()
    var startIter = startStream.makeAsyncIterator()

    let task = QueryTask<Int>(context: QueryContext()) { _, _ in
      startContinuation.yield()
      return try await Task.never()
    }
    Task { try await task.runIfNeeded() }
    await startIter.next()
    expectNoDifference(task.isFinished, false)
  }

  @Test("QueryTask Is Finished After Running")
  func queryTaskIsFinishedAfterRunning() async throws {
    let task = QueryTask<Int>(context: QueryContext()) { _, _ in 42 }
    _ = try await task.runIfNeeded()
    expectNoDifference(task.isFinished, true)
  }

  @Test("QueryTask Is Finished When Cancelled")
  func queryTaskIsFinishedWhenCancelled() async throws {
    let task = QueryTask<Int>(context: QueryContext()) { _, _ in 42 }
    task.cancel()
    expectNoDifference(task.isFinished, true)
  }

  @Test("QueryTask No Finished Result Before Running")
  func queryTaskNoFinishedResultBeforeRunning() async throws {
    let task = QueryTask<Int>(context: QueryContext()) { _, _ in 42 }
    expectNoDifference(try task.finishedResult?.get(), nil)
  }

  @Test("QueryTask Has Finished Result After Running")
  func queryTaskHasFinishedResultAfterRunning() async throws {
    let task = QueryTask<Int>(context: QueryContext()) { _, _ in 42 }
    _ = try await task.runIfNeeded()
    expectNoDifference(try task.finishedResult?.get(), 42)
  }

  @Test("QueryTask Has Error Finished Result After Running When Map Throws")
  func queryTaskHasErrorFinishedResultAfterRunningWhenMapThrows() async throws {
    struct SomeError: Error {}

    let task = QueryTask<Int>(context: QueryContext()) { _, _ in 42 }
      .map { _ in throw SomeError() }
    _ = try? await task.runIfNeeded()
    #expect(throws: SomeError.self) { try task.finishedResult?.get() }
  }

  @Test("QueryTask Is Not Running By Default")
  func queryTaskIsNotRunningByDefault() {
    let task = QueryTask(context: QueryContext()) { _, _ in 42 }
    expectNoDifference(task.isRunning, false)
  }

  @Test("QueryTask Is Not Running When Cancelled")
  func queryTaskIsNotRunningWhenCancelled() {
    let task = QueryTask(context: QueryContext()) { _, _ in 42 }
    task.cancel()
    expectNoDifference(task.isRunning, false)
  }

  @Test("QueryTask Is Not Running When Finished")
  func queryTaskIsNotRunningByDefault() async throws {
    let task = QueryTask(context: QueryContext()) { _, _ in 42 }
    _ = try await task.runIfNeeded()
    expectNoDifference(task.isRunning, false)
  }

  @Test("QueryTask Is Running When Loading")
  func queryTaskIsRunningWhenLoading() async {
    let (startStream, startContinuation) = AsyncStream<Void>.makeStream()
    var startIter = startStream.makeAsyncIterator()

    let task = QueryTask(context: QueryContext()) { _, _ in
      startContinuation.yield()
      try await Task.never()
    }
    Task { try await task.runIfNeeded() }
    await startIter.next()
    expectNoDifference(task.isRunning, true)
  }

  @Test("Has Running Task Id In Context When Running")
  func hasRunningTaskIdInContextWhenRunning() async throws {
    let task = QueryTask(context: QueryContext()) { id, context in
      expectNoDifference(context.queryRunningTaskIdentifier, id)
    }
    expectNoDifference(task.context.queryRunningTaskIdentifier, nil)
    try await task.runIfNeeded()
    expectNoDifference(task.context.queryRunningTaskIdentifier, nil)
  }

  #if compiler(>=6.2)
    @Test("Runs On Executor Preference")
    @available(iOS 26.0, macOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
    func runsOnExecutorPreference() async throws {
      final class ImmediateExecutor: TaskExecutor {
        func asUnownedTaskExecutor() -> UnownedTaskExecutor {
          UnownedTaskExecutor(ordinary: self)
        }

        func enqueue(_ job: consuming ExecutorJob) {
          let job = UnownedJob(job)
          Task {
            job.runSynchronously(on: self.asUnownedTaskExecutor())
          }
        }
      }

      let executor = ImmediateExecutor()
      var task = QueryTask<Bool>(context: QueryContext()) { _, _ in
        Task.currentExecutor === executor
      }
      task.configuration.executorPreference = executor
      let didRunOnExecutor = try await task.runIfNeeded()
      expectNoDifference(didRunOnExecutor, true)
    }
  #endif

  #if DEBUG
    @Test("Reports Issue When Circular Scheduling, 2 Tasks")
    func reportsIssueWhenCircularScheduling2Tasks() async throws {
      var context = QueryContext()
      context.queryTaskConfiguration = QueryTaskConfiguration(name: "Test task 1")
      let task1 = QueryTask<Int>(context: context) { _, _ in 40 }

      context.queryTaskConfiguration = QueryTaskConfiguration(name: "Test task 2")
      let task2 = QueryTask<Int>(context: context) { _, _ in 32 }
      task1.schedule(after: task2)
      withKnownIssue {
        task2.schedule(after: task1)
      } matching: { [task1, task2] issue in
        issue.comments.contains(
          .warning(
            .queryTaskCircularScheduling(info: [
              task2.info, task1.info, task2.info
            ])
          )
        )
      }
    }

    @Test("Reports Issue When Circular Scheduling, 3 Tasks")
    func reportsIssueWhenCircularScheduling3Tasks() async throws {
      var context = QueryContext()
      context.queryTaskConfiguration = QueryTaskConfiguration(name: "Test task 1")
      let task1 = QueryTask<Int>(context: context) { _, _ in 40 }

      context.queryTaskConfiguration = QueryTaskConfiguration(name: "Test task 2")
      let task2 = QueryTask<Int>(context: context) { _, _ in 32 }

      context.queryTaskConfiguration = QueryTaskConfiguration(name: "Test task 3")
      let task3 = QueryTask<Int>(context: context) { _, _ in 24 }

      context.queryTaskConfiguration = QueryTaskConfiguration(name: "Test task 4")
      let task4 = QueryTask<Int>(context: context) { _, _ in 16 }
      task1.schedule(after: task2)
      task2.schedule(after: task3)
      task3.schedule(after: task4)
      withKnownIssue {
        task3.schedule(after: task1)
      } matching: { [task1, task2, task3] issue in
        issue.comments.contains(
          .warning(
            .queryTaskCircularScheduling(info: [
              task3.info, task1.info, task2.info, task3.info
            ])
          )
        )
      }
    }
  #endif
}
