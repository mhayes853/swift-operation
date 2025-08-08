import ConcurrencyExtras
import IdentifiedCollections

// TODO: - Could this be a modifier in the library at some point?

public final actor SerialTaskQueue {
  private let priority: TaskPriority
  private var currentId = 0
  private var queue = IdentifiedArrayOf<TaskState>()

  public init(priority: TaskPriority) {
    self.priority = priority
  }

  public func run<T: Sendable>(
    _ task: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    let runnerId = self.currentId
    self.currentId += 1

    let state = TaskState(id: runnerId) { try await task() }
    for i in 0..<self.queue.count {
      self.queue[i].count += 1
    }
    self.queue.append(state)

    var result: Result<any Sendable, any Error>?

    let ids = self.queue.ids
    for id in ids {
      let state = self.queue[id: id]!
      let task = self.queue[id: id]!.task ?? Task(priority: self.priority) { try await state.fn() }
      self.queue[id: id]!.task = task
      result = await Result { try await task.cancellableValue }
      self.queue[id: id]!.count -= 1
      if self.queue[id: id]!.count == 0 {
        self.queue.remove(id: id)
      }
      if id == runnerId {
        break
      }
    }
    return try result!.map { $0 as! T }.get()
  }
}

extension SerialTaskQueue {
  private struct TaskState: Sendable, Identifiable {
    let id: Int
    var count = 1
    var fn: @Sendable () async throws -> any Sendable
    var task: Task<any Sendable, any Error>?
  }
}
