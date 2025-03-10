import CustomDump
@_spi(Warnings) import QueryCore
import Testing

@Suite("QueryTask tests")
struct QueryTaskTests {
  @Test("Task With Dependencies, Runs Dependent Tasks")
  func runsDependentTasks() async throws {
    let runCount = Lock(0)

    let task1 = QueryTask<Int>(context: QueryContext()) { 40 }
    let task2 = QueryTask<Int>(context: QueryContext()) {
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

    let task1 = QueryTask<Int>(context: QueryContext()) { 40 }
    let task2 = QueryTask<Int>(context: QueryContext()) { throw SomeError() }
    task1.schedule(after: task2)
    await #expect(throws: Never.self) {
      _ = try await task1.runIfNeeded()
    }
  }

  #if DEBUG
    @Test("Reports Issue When Circular Scheduling, 2 Tasks")
    func reportsIssueWhenCircularScheduling2Tasks() async throws {
      let context = QueryContext()
      let task1 = QueryTask<Int>(context: context) { 40 }
      let task2 = QueryTask<Int>(context: context) { 32 }
      task1.schedule(after: task2)
      withKnownIssue {
        task2.schedule(after: task1)
      } matching: { [task1, task2] issue in
        issue.comments.contains(
          .warning(.queryTaskCircularScheduling(ids: [task2.id, task1.id, task2.id]))
        )
      }
    }

    @Test("Reports Issue When Circular Scheduling, 3 Tasks")
    func reportsIssueWhenCircularScheduling3Tasks() async throws {
      let context = QueryContext()
      let task1 = QueryTask<Int>(context: context) { 40 }
      let task2 = QueryTask<Int>(context: context) { 32 }
      let task3 = QueryTask<Int>(context: context) { 24 }
      let task4 = QueryTask<Int>(context: context) { 16 }
      task1.schedule(after: task2)
      task2.schedule(after: task3)
      task3.schedule(after: task4)
      withKnownIssue {
        task3.schedule(after: task1)
      } matching: { [task1, task2, task3] issue in
        issue.comments.contains(
          .warning(.queryTaskCircularScheduling(ids: [task3.id, task1.id, task2.id, task3.id]))
        )
      }
    }
  #endif
}
