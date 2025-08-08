import DequeModule
import Synchronization

// TODO: - Could this be a modifier in the library at some point?

// MARK: - SerialTaskQueue

public final actor SerialTaskQueue {
  private let priority: TaskPriority
  private var drainTask: Task<Void, Never>?
  private var queue = Deque<QueueTask>()

  public init(priority: TaskPriority) {
    self.priority = priority
  }

  public func run<T: Sendable>(
    _ task: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    let queueTask = QueueTask()
    return try await withTaskCancellationHandler {
      try await withUnsafeThrowingContinuation { continuation in
        queueTask.schedule(continuation: continuation, task)
        self.queue.append(queueTask)
        self.beginDrainingIfNeeded()
      }
    } onCancel: {
      queueTask.cancel()
    }
  }

  private func beginDrainingIfNeeded() {
    guard self.drainTask == nil else { return }
    self.drainTask = Task {
      while let task = self.queue.popFirst() {
        await task.run(with: self.priority)
      }
      self.drainTask = nil
    }
  }
}

// MARK: - QueueTask

extension SerialTaskQueue {
  private final class QueueTask: Sendable {
    private struct State {
      var fn: (@Sendable () async -> Void)?
      var onCancel: (@Sendable () -> Void)?
      var isCancelled = false
      var task: Task<Void, Never>?
    }

    private let state = Mutex(State())

    func schedule<T: Sendable>(
      continuation: UnsafeContinuation<T, any Error>,
      _ fn: @escaping @Sendable () async throws -> T
    ) {
      self.state.withLock { state in
        state.fn = {
          do {
            let value = try await fn()
            continuation.resume(returning: value)
          } catch {
            if !(error is CancellationError) {
              continuation.resume(throwing: error)
            }
          }
        }
        state.onCancel = { continuation.resume(throwing: CancellationError()) }
      }
    }

    func cancel() {
      self.state.withLock { state in
        state.isCancelled = true
        state.onCancel?()
        state.task?.cancel()
      }
    }

    func run(with priority: TaskPriority) async {
      let task: Task<Void, Never>? = self.state.withLock { state in
        guard let fn = state.fn, !state.isCancelled, state.task == nil else { return nil }
        state.task = Task(priority: priority) { await fn() }
        return state.task
      }
      await task?.value
    }
  }
}
