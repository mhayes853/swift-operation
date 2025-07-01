import Foundation

// MARK: - _QueryTask

private protocol _QueryTask: Sendable, Identifiable {
  var id: QueryTaskIdentifier { get }
  var info: QueryTaskInfo { get }
  var dependencies: [any _QueryTask] { get }

  func _runIfNeeded() async throws -> any Sendable

  #if DEBUG
    func warnIfCyclesDetected(cyclicalIds: [QueryTaskInfo], visited: Set<QueryTaskIdentifier>)
  #endif
}

// MARK: - QueryTask

/// A unit of work for systems that manage the execution and state of a ``QueryRequest``.
///
/// Generally, `QueryTask`s are created by ``QueryStore``s, and then are retained within the
/// store's state. In other words, you generally do not create tasks directly, but you can
/// retrieve tasks from the store and configure their creation through ``QueryTaskConfiguration``.
///
/// Unlike a traditional `Task` in Swift, a `QueryTask` does not immediately begin scheduling its
/// work on its preferred executor when initialized. Instead, you must explicitly schedule and
/// run the task using ``runIfNeeded()``, and you can check the running state via ``isRunning``
/// and ``hasStarted``. Once `runIfNeeded` has been called, subsequent calls to
/// `runIfNeeded` will await an underyling `Task` created by the first call. You can configure
/// the properties for this underlying task through `QueryTaskConfiguration`.
///
/// `QueryTask` itself is a value type, and contains mutable properties (most notable
/// ``configuration``). However, the underlying mechanism for the scheduling and run state is
/// managed via a reference. Therefore, copied values of a task will point to the same underlying
/// reference for the task's run state, including those returned from helpers such as ``map(_:)``.
/// Once a task has begun running, any mutations to the task's mutable properties will have no
/// effect on the active work.
///
/// Each `QueryTask` is paired with a unique ``QueryTaskIdentifier``, allowing it to conform to
/// `Identifiable`. This identifier is also used to implement `Hashable` and `Equatable` just like
/// the way it works for traditional Swift `Task` values. Copied tasks, including those from
/// helpers such as `map` will retain the same id, and therefore are equal.
public struct QueryTask<Value: Sendable>: _QueryTask {
  private typealias State = (task: TaskState?, dependencies: [any _QueryTask])

  public let id: QueryTaskIdentifier

  /// The current ``QueryContext`` for this task.
  ///
  /// > Note: Mutating this property after calling ``runIfNeeded()`` has no effect on the
  /// > active work.
  public var context: QueryContext

  private let work: @Sendable (QueryTaskIdentifier, QueryContext) async throws -> any Sendable
  private let transforms: @Sendable (any Sendable) throws -> Value
  private let box: LockedBox<State>
}

extension QueryTask {
  /// Creates a task.
  ///
  /// - Parameters:
  ///   - context: The ``QueryContext`` for the task.
  ///   - work: The task's actual work.
  public init(
    context: QueryContext,
    work: @escaping @Sendable (QueryTaskIdentifier, QueryContext) async throws -> Value
  ) {
    self.id = .next()
    self.context = context
    self.work = work
    self.transforms = { $0 as! Value }
    self.box = LockedBox(value: (nil, []))
  }
}

// MARK: - QueryTaskConfiguration

extension QueryTask {
  /// The current ``QueryTaskConfiguration`` for this task.
  ///
  /// > Note: Mutating this property after calling ``runIfNeeded()`` has no effect on the
  /// > active work.
  public var configuration: QueryTaskConfiguration {
    get { self.context.queryTaskConfiguration }
    set { self.context.queryTaskConfiguration = newValue }
  }
}

// MARK: - QueryTaskID

/// An opaque identifier for a ``QueryTask``.
///
/// Each new `QueryTask` is assigned a unique identifier when it is initialized, you do not create
/// instances of this identifier.
public struct QueryTaskIdentifier: Hashable, Sendable {
  private let number: Int
}

extension QueryTaskIdentifier {
  private static let counter = Lock(0)

  fileprivate static func next() -> Self {
    counter.withLock { counter in
      defer { counter += 1 }
      return Self(number: counter)
    }
  }
}

extension QueryTaskIdentifier: CustomDebugStringConvertible {
  public var debugDescription: String {
    "#\(self.number)"
  }
}

// MARK: - Equatable

extension QueryTask: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: - Hashable

extension QueryTask: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
}

// MARK: - Task Dependencies

extension QueryTask {
  /// Schedules the execution of this task to take place after another task.
  ///
  /// > Note: Calling this method after calling ``runIfNeeded()`` has no effect.
  ///
  /// - Parameter task: The task to schedule this task's execution after.
  public func schedule<V: Sendable>(after task: QueryTask<V>) {
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
  public func schedule<V: Sendable>(after tasks: some Sequence<QueryTask<V>>) {
    self.withDependencies {
      let ids = Set(tasks.map(\.id))
      $0.removeAll { ids.contains($0.info.id) }
      $0.append(contentsOf: tasks.removeFirstDuplicates(by: \.id))
    }
  }

  private func withDependencies(_ fn: (inout [any _QueryTask]) -> Void) {
    self.box.inner.withLock { fn(&$0.dependencies) }
    #if DEBUG
      self.warnIfCyclesDetected(cyclicalIds: [self.info], visited: [self.id])
    #endif
  }

  #if DEBUG
    func warnIfCyclesDetected(
      cyclicalIds: [QueryTaskInfo],
      visited: Set<QueryTaskIdentifier>
    ) {
      for dependency in self.dependencies {
        if visited.contains(dependency.id) {
          reportWarning(.queryTaskCircularScheduling(info: cyclicalIds + [dependency.info]))
        } else {
          dependency.warnIfCyclesDetected(
            cyclicalIds: cyclicalIds + [dependency.info],
            visited: visited.union([dependency.id])
          )
        }
      }
    }
  #endif

  fileprivate var dependencies: [any _QueryTask] {
    self.box.inner.withLock { $0.dependencies }
  }
}

// MARK: - Run

extension QueryTask {
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
  /// running. While `QueryTask` is a value type, all of its copies, even those produced by helpers
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
    case let .awaitTask(task):
      return try await withTaskCancellationHandler {
        try await task.value
      } onCancel: {
        self.cancel()
      }
    case let .returnValue(value):
      return value
    }
  }

  private func runTaskAction() throws -> RunAction {
    try self.box.inner.withLock { state in
      switch state.task {
      case let .running(task):
        return RunAction.awaitTask(task)
      case let .finished(result):
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
    context.queryRunningTaskIdentifier = self.id
    return Task(configuration: info.configuration) {
      try await self.performTask(context: context)
    }
  }

  private func performTask(context: QueryContext) async throws -> any Sendable {
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

extension QueryTask {
  /// Whether or not this task has been finished with a `CancellationError`.
  public var isCancelled: Bool {
    self.box.inner.withLock {
      switch $0.task {
      case let .finished(.failure(error)): error is CancellationError
      default: false
      }
    }
  }

  /// Cancels this task.
  ///
  /// `QueryTask` cancellation behaves differently based on the running state of the task.
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
      case let .running(task): task.cancel()
      case .finished: return
      default: break
      }
      $0.task = .finished(.failure(CancellationError()))
    }
  }
}

// MARK: - Is Finished

extension QueryTask {
  /// Whether or not this task has finished running.
  public var isFinished: Bool {
    self.box.inner.withLock {
      switch $0.task {
      case .finished: true
      default: false
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

extension QueryTask {
  /// Returns a new `QueryTask` that applies a transformation to this work's return value of this
  /// task.
  ///
  /// The new `QueryTask` has the same ``QueryTaskIdentifier``, and points to the same underlying
  /// reference as this task. This means that the 2 tasks remain equivalent with each other
  /// according to `Hashable` and `Equatable`, and that their running states will be equivalent.
  /// When ``runIfNeeded()`` is called on either task, both will be in a running state.
  ///
  /// - Parameter transform: A closure to transform the work's return value from this task.
  /// - Returns: A new `QueryTask` with the new work return value that has the same underlying reference an identifier as this task.
  public func map<T: Sendable>(
    _ transform: @escaping @Sendable (Value) throws -> T
  ) -> QueryTask<T> {
    QueryTask<T>(
      id: self.id,
      context: self.context,
      work: self.work,
      transforms: { try transform(self.transforms($0)) },
      box: self.box
    )
  }
}

// MARK: - QueryContext

extension QueryContext {
  /// The ``QueryTaskIdentifier`` of the currently running task, if any.
  public var queryRunningTaskIdentifier: QueryTaskIdentifier? {
    get { self[QueryRunningTaskIdentifierKey.self] }
    set { self[QueryRunningTaskIdentifierKey.self] = newValue }
  }

  private enum QueryRunningTaskIdentifierKey: Key {
    static var defaultValue: QueryTaskIdentifier? {
      nil
    }
  }
}

// MARK: - Warnings

extension QueryWarning {
  public static func queryTaskCircularScheduling(info: [QueryTaskInfo]) -> Self {
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
