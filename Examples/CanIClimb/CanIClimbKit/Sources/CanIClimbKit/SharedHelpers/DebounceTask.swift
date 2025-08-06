public final class DebounceTask {
  private let clock: any Clock<Duration>
  private let operation: @Sendable () async throws -> Void
  private var task: Task<Void, any Error>?
  private let duration: Duration

  public init(
    clock: any Clock<Duration>,
    duration: Duration,
    operation: @escaping @Sendable () async throws -> Void
  ) {
    self.clock = clock
    self.operation = operation
    self.duration = duration
  }

  deinit { self.cancel() }

  public func schedule() {
    self.cancel()
    let clock = self.clock
    let operation = self.operation
    let duration = self.duration
    self.task = Task(priority: .userInitiated) {
      try await clock.sleep(for: duration)
      try await operation()
    }
  }

  public func cancel() {
    self.task?.cancel()
  }
}
