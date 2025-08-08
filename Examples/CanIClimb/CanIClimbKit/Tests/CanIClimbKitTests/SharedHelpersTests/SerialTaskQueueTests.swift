import CanIClimbKit
import CustomDump
import Synchronization
import Testing

@Suite("SerialTaskQueue tests")
struct SerialTaskQueueTests {
  @Test("Always Runs Serially")
  func alwaysRunsSerially() async throws {
    let queue = SerialTaskQueue(priority: .high)
    let pattern = Pattern()

    let t1 = Task { @Sendable in
      try await queue.run { await pattern.appendRound(id: "a") }
    }
    let t2 = Task { @Sendable in
      try await queue.run { await pattern.appendRound(id: "b") }
    }
    let t3 = Task { @Sendable in
      try await queue.run { await pattern.appendRound(id: "c") }
    }
    _ = try await (t1.value, t2.value, t3.value)

    let isSerially = await pattern.areRoundsSeriallyAppended
    expectNoDifference(isSerially, true)
  }

  @Test("Throws Error From Queued Tasks")
  func throwsErrorFromQueuedTask() async throws {
    struct SomeError: Error {}
    let queue = SerialTaskQueue(priority: .high)
    
    await #expect(throws: SomeError.self) {
      try await queue.run { throw SomeError() }
    }
  }

  @Test("Handles Cancellation Properly")
  func handlesCancellationProperly() async throws {
    let queue = SerialTaskQueue(priority: .high)

    let task = Task {
      try await queue.run { try await Task.never() }
    }
    task.cancel()

    try await confirmation { confirm in
      try await queue.run { confirm() }
    }
  }
}

private final actor Pattern {
  private(set) var pattern = ""

  var areRoundsSeriallyAppended: Bool {
    // NB: A serially appended string would look like the following because every round must have
    // been appended without any interleaving.
    //
    // "aaabbbccc" -> true
    // "abaacbccb" -> false

    guard !self.pattern.isEmpty else { return false }

    var previous = Set<Character>()
    var current = self.pattern.first!

    for char in self.pattern {
      if previous.contains(char) {
        return false
      }
      if current != char {
        previous.insert(current)
      }
      current = char
    }
    return true
  }

  func append(id: Character) {
    self.pattern.append(id)
  }

  nonisolated func appendRound(id: Character) async {
    for _ in 0..<100 {
      await self.append(id: id)
    }
  }
}
