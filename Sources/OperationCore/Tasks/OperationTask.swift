import Foundation

// MARK: - _OperationTask

private protocol _OperationTask: Sendable, Identifiable {
  var id: OperationTaskIdentifier { get }
  var info: OperationTaskInfo { get }
  var dependencies: [any _OperationTask] { get }

  func _runIfNeeded() async throws -> any Sendable

  #if DEBUG
    func warnIfCyclesDetected(
      cyclicalIds: [OperationTaskInfo],
      visited: Set<OperationTaskIdentifier>
    )
  #endif
}

// MARK: - OperationTask

/// A unit of work for systems that manage the execution and state of a ``QueryRequest``.
///
/// Generally, `OperationTask`s are created by ``OperationStore``s, and then are retained within the
/// store's state. In other words, you generally do not create tasks directly, but you can
/// retrieve tasks from the store and configure their creation through ``OperationTaskConfiguration``.
///
/// Unlike a traditional `Task` in Swift, a `OperationTask` does not immediately begin scheduling its
/// work on its preferred executor when initialized. Instead, you must explicitly schedule and
/// run the task using ``runIfNeeded()``, and you can check the running state via ``isRunning``
/// and ``hasStarted``. Once `runIfNeeded` has been called, subsequent calls to
/// `runIfNeeded` will await an underyling `Task` created by the first call. You can configure
/// the properties for this underlying task through `OperationTaskConfiguration`.
///
/// `OperationTask` itself is a value type, and contains mutable properties (most notable
/// ``configuration``). However, the underlying mechanism for the scheduling and run state is
/// managed via a reference. Therefore, copied values of a task will point to the same underlying
/// reference for the task's run state, including those returned from helpers such as ``map(_:)``.
/// Once a task has begun running, any mutations to the task's mutable properties will have no
/// effect on the active work.
///
/// Each `OperationTask` is paired with a unique ``OperationTaskIdentifier``, allowing it to conform to
/// `Identifiable`. This identifier is also used to implement `Hashable` and `Equatable` just like
/// the way it works for traditional Swift `Task` values. Copied tasks, including those from
/// helpers such as `map` will retain the same id, and therefore are equal.
public struct OperationTask<Value: Sendable>: _OperationTask {
  private typealias State = (task: TaskState?, dependencies: [any _OperationTask])

  public let id: OperationTaskIdentifier

  /// The current ``OperationContext`` for this task.
  ///
  /// > Note: Mutating this property after calling ``runIfNeeded()`` has no effect on the
  /// > active work.
  public var context: OperationContext

  private let work:
    @Sendable (OperationTaskIdentifier, OperationContext) async throws -> any Sendable
  private let transforms: @Sendable (any Sendable) throws -> Value
  private let box: LockedBox<State>
}

extension OperationTask {
  /// Creates a task.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` for the task.
  ///   - work: The task's actual work.
  public init(
    context: OperationContext,
    work: @escaping @Sendable (OperationTaskIdentifier, OperationContext) async throws -> Value
  ) {
    self.id = .next()
    self.context = context
    self.work = work
    self.transforms = { $0 as! Value }
    self.box = LockedBox(value: (nil, []))
  }
}

// MARK: - OperationTaskConfiguration

extension OperationTask {
  /// The current ``OperationTaskConfiguration`` for this task.
  ///
  /// > Note: Mutating this property after calling ``runIfNeeded()`` has no effect on the
  /// > active work.
  public var configuration: OperationTaskConfiguration {
    get { self.context.operationTaskConfiguration }
    set { self.context.operationTaskConfiguration = newValue }
  }
}

// MARK: - Equatable

extension OperationTask: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: - Hashable

extension OperationTask: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
}

// MARK: - Task Dependencies

extension OperationTask {
  /// Schedules the execution of this task to take place after another task.
  ///
  /// > Note: Calling this method after calling ``runIfNeeded()`` has no effect.
  ///
  /// - Parameter task: The task to schedule this task's execution after.
  public func schedule<V: Sendable>(after task: OperationTask<V>) {
    self.withDependencies {
      $0.removeAll { $0.id == task.id }
      $0.append(task)
    }
  }

  /// Schedules the execution of this task to take place after a sequence of other tasks.
  ///
  /// > Note: Calling this method after calling ``runIfNeeded()`` has no effect.
  ///
  /// - Parameter tasks: The sequence of tasks to schedule this task's execution after.
  public func schedule<V: Sendable>(after tasks: some Sequence<OperationTask<V>>) {
    self.withDependencies {
      let ids = Set(tasks.map(\.id))
      $0.removeAll { ids.contains($0.info.id) }
      $0.append(contentsOf: tasks.removeFirstDuplicates(by: \.id))
    }
  }

  private func withDependencies(_ fn: (inout [any _OperationTask]) -> Void) {
    self.box.inner.withLock { fn(&$0.dependencies) }
    #if DEBUG
      self.warnIfCyclesDetected(cyclicalIds: [self.info], visited: [self.id])
    #endif
  }

  #if DEBUG
    func warnIfCyclesDetected(
      cyclicalIds: [OperationTaskInfo],
      visited: Set<OperationTaskIdentifier>
    ) {
      for dependency in self.dependencies {
        if visited.contains(dependency.id) {
          reportWarning(.OperationTaskCircularScheduling(info: cyclicalIds + [dependency.info]))
        } else {
          dependency.warnIfCyclesDetected(
            cyclicalIds: cyclicalIds + [dependency.info],
            visited: visited.union([dependency.id])
          )
        }
      }
    }
  #endif

  fileprivate var dependencies: [any _OperationTask] {
    self.box.inner.withLock { $0.dependencies }
  }
}

// MARK: - Run

extension OperationTask {
  /// Whether or not the task has been started in some capacity.
  ///
  /// The difference between this property, and ``isRunning`` is that this property will remain
  /// true after a task has finished.
  public var hasStarted: Bool {
    self.box.inner.withLock { $0.task != nil }
  }

  /// Whether or not the task is actively running.
  ///
  /// The difference between this property, and ``hasStarted`` is that this property will return
  /// false after a task has finished.
  public var isRunning: Bool {
    self.box.inner.withLock {
      switch $0.task {
      case .running: true
      default: false
      }
    }
  }

  /// Runs this task if it has not already been started.
  ///
  /// If the task has already been started, then this method will await the active work instead of
  /// spinning up a new instance of the work. If the task has already finished, then the finished
  /// result is returned immediately instead of spinning up a new instance of the work.
  ///
  /// Calling this method mutates a shared reference under the hood to indicate that the task is
  /// running. While `OperationTask` is a value type, all of its copies, even those produced by helpers
  /// such as ``map(_:)``, will be in a running state.
  ///
  /// > Note: After calling this method, mutations to the task's mutable properties will have no
  /// > effect on the task's active work.
  ///
  /// - Returns: The return value of the active work.
  public func runIfNeeded() async throws -> Value {
    try await self.transforms(self._runIfNeeded())
  }

  fileprivate func _runIfNeeded() async throws -> any Sendable {
    switch try self.runTaskAction() {
    case .awaitTask(let task):
      return try await withTaskCancellationHandler {
        try await task.value
      } onCancel: {
        self.cancel()
      }
    case .returnValue(let value):
      return value
    }
  }

  private func runTaskAction() throws -> RunAction {
    try self.box.inner.withLock { state in
      switch state.task {
      case .running(let task):
        return RunAction.awaitTask(task)
      case .finished(let result):
        return try .returnValue(result.get())
      case .none:
        let task = self.newTask()
        state.task = .running(task)
        return .awaitTask(task)
      }
    }
  }

  private func newTask() -> Task<any Sendable, any Error> {
    var context = self.context
    context.operationRunningTaskIdentifier = self.id
    return Task(configuration: info.configuration) {
      try await self.performTask(context: context)
    }
  }

  private func performTask(context: OperationContext) async throws -> any Sendable {
    await withTaskGroup(of: Void.self) { group in
      for dependency in self.dependencies {
        group.addTask { _ = try? await dependency._runIfNeeded() }
      }
    }
    let result = await Result {
      let value = try await self.work(self.id, context) as any Sendable
      try Task.checkCancellation()
      return value
    }
    self.box.inner.withLock { $0.task = .finished(result) }
    return try result.get()
  }

  private enum RunAction {
    case awaitTask(Task<any Sendable, any Error>)
    case returnValue(any Sendable)
  }
}

// MARK: - Cancellation

extension OperationTask {
  /// Whether or not this task has been finished with a `CancellationError`.
  public var isCancelled: Bool {
    self.box.inner.withLock {
      switch $0.task {
      case .finished(.failure(let error)): error is CancellationError
      default: false
      }
    }
  }

  /// Cancels this task.
  ///
  /// `OperationTask` cancellation behaves differently based on the running state of the task.
  ///
  /// - If the task is not running, and ``hasStarted`` is false, then the running state of the task
  /// is immediately set to a finished state with a `CancellationError`.
  ///
  /// - If the task is running (ie. ``isRunning`` is true), the underlying `Task` value is
  /// cancelled normally.
  ///
  /// - If the task has already finished (ie. ``isFinished`` is true), then this method has no
  /// effect.
  public func cancel() {
    self.box.inner.withLock {
      switch $0.task {
      case .running(let task): task.cancel()
      case .finished: return
      default: break
      }
      $0.task = .finished(.failure(CancellationError()))
    }
  }
}

// MARK: - Is Finished

extension OperationTask {
  /// Whether or not this task has finished running.
  public var isFinished: Bool {
    self.box.inner.withLock {
      switch $0.task {
      case .finished: true
      default: false
      }
    }
  }

  /// The result of this task, if it has finished running.
  public var finishedResult: Result<Value, any Error>? {
    self.box.inner.withLock {
      switch $0.task {
      case .finished(let result):
        result.flatMap { value in Result { try self.transforms(value) } }
      default:
        nil
      }
    }
  }
}

// MARK: - TaskState

private enum TaskState {
  case finished(Result<any Sendable, any Error>)
  case running(Task<any Sendable, any Error>)
}

// MARK: - Map

extension OperationTask {
  /// Returns a new `OperationTask` that applies a transformation to this work's return value of this
  /// task.
  ///
  /// The new `OperationTask` has the same ``OperationTaskIdentifier``, and points to the same underlying
  /// reference as this task. This means that the 2 tasks remain equivalent with each other
  /// according to `Hashable` and `Equatable`, and that their running states will be equivalent.
  /// When ``runIfNeeded()`` is called on either task, both will be in a running state.
  ///
  /// - Parameter transform: A closure to transform the work's return value from this task.
  /// - Returns: A new `OperationTask` with the new work return value that has the same underlying reference an identifier as this task.
  public func map<T: Sendable>(
    _ transform: @escaping @Sendable (Value) throws -> T
  ) -> OperationTask<T> {
    OperationTask<T>(
      id: self.id,
      context: self.context,
      work: self.work,
      transforms: { try transform(self.transforms($0)) },
      box: self.box
    )
  }
}

// MARK: - Warnings

extension OperationWarning {
  public static func OperationTaskCircularScheduling(info: [OperationTaskInfo]) -> Self {
    Self(
      """
      Circular scheduling detected for tasks.

        Cycle:

        \(info.map(\.description).joined(separator: " -> "))

      This will cause task starvation when running any of the tasks in this cycle.
      """
    )
  }
}
