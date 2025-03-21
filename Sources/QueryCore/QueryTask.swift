import ConcurrencyExtras
import Foundation

// MARK: - _QueryTask

private protocol _QueryTask: Sendable, Identifiable {
  var id: QueryTaskIdentifier { get }
  var info: QueryTaskInfo { get }
  var dependencies: [any _QueryTask] { get }

  func _runIfNeeded() async throws -> any Sendable
  func warnIfCyclesDetected(cyclicalIds: [QueryTaskInfo], visited: Set<QueryTaskIdentifier>)
}

// MARK: - QueryTask

public struct QueryTask<Value: Sendable>: _QueryTask {
  private typealias State = (task: TaskState?, dependencies: [any _QueryTask])

  public var info: QueryTaskInfo

  public var context: QueryContext

  private let work: @Sendable (QueryContext) async throws -> any Sendable
  private let transforms: @Sendable (any Sendable) throws -> Value
  private let box: LockedBox<State>
}

extension QueryTask {
  public init(
    name: String? = nil,
    context: QueryContext,
    work: @escaping @Sendable (QueryContext) async throws -> Value
  ) {
    self.info = QueryTaskInfo(name: name)
    self.context = context
    self.work = work
    self.transforms = { $0 as! Value }
    self.box = LockedBox(value: (nil, []))
  }
}

// MARK: - Info

extension QueryTask {
  public var name: String? {
    get { self.info.name }
    set { self.info.name = newValue }
  }
}

// MARK: - QueryTaskID

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

// MARK: - Identifiable

extension QueryTask: Identifiable {
  public var id: QueryTaskIdentifier {
    self.info.id
  }
}

// MARK: - Equatable

extension QueryTask: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.info.id == rhs.info.id
  }
}

// MARK: - Hashable

extension QueryTask: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.info.id)
  }
}

// MARK: - Task Dependencies

extension QueryTask {
  public func schedule<V: Sendable>(after task: QueryTask<V>) {
    self.withDependencies {
      $0.removeAll { $0.info.id == task.info.id }
      $0.append(task)
    }
  }

  public func schedule<V: Sendable>(after tasks: some Sequence<QueryTask<V>>) {
    self.withDependencies {
      let ids = Set(tasks.map(\.info.id))
      $0.removeAll { ids.contains($0.info.id) }
      $0.append(contentsOf: tasks.removeFirstDuplicates(by: \.info.id))
    }
  }

  private func withDependencies(_ fn: (inout [any _QueryTask]) -> Void) {
    self.box.inner.withLock { fn(&$0.dependencies) }
    self.warnIfCyclesDetected(cyclicalIds: [self.info], visited: [self.info.id])
  }

  fileprivate func warnIfCyclesDetected(
    cyclicalIds: [QueryTaskInfo],
    visited: Set<QueryTaskIdentifier>
  ) {
    #if DEBUG
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
    #endif
  }

  fileprivate var dependencies: [any _QueryTask] {
    self.box.inner.withLock { $0.dependencies }
  }
}

// MARK: - Run

extension QueryTask {
  public var hasStarted: Bool {
    self.box.inner.withLock { $0.task != nil }
  }

  public var isRunning: Bool {
    self.box.inner.withLock {
      switch $0.task {
      case .running: true
      default: false
      }
    }
  }

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
    context.queryRunningTaskInfo = self.info
    return Task {
      await withTaskGroup(of: Void.self) { group in
        for dependency in self.dependencies {
          group.addTask { _ = try? await dependency._runIfNeeded() }
        }
      }
      let result = await Result { try await self.work(context) as any Sendable }
      self.box.inner.withLock { $0.task = .finished(result) }
      return try result.get()
    }
  }

  private enum RunAction {
    case awaitTask(Task<any Sendable, any Error>)
    case returnValue(any Sendable)
  }
}

// MARK: - Cancellation

extension QueryTask {
  public var isCancelled: Bool {
    self.box.inner.withLock {
      switch $0.task {
      case let .finished(.failure(error)): error is CancellationError
      default: false
      }
    }
  }

  public func cancel() {
    self.box.inner.withLock {
      switch $0.task {
      case let .running(task): task.cancel()
      default: break
      }
      $0.task = .finished(.failure(CancellationError()))
    }
  }
}

// MARK: - Is Finished

extension QueryTask {
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
  public func map<T: Sendable>(
    _ transform: @escaping @Sendable (Value) throws -> T
  ) -> QueryTask<T> {
    QueryTask<T>(
      info: self.info,
      context: self.context,
      work: self.work,
      transforms: { try transform(self.transforms($0)) },
      box: self.box
    )
  }
}

// MARK: - Info

public struct QueryTaskInfo: Hashable, Sendable, Identifiable {
  public let id: QueryTaskIdentifier
  public var name: String?

  public init(name: String? = nil) {
    self.id = .next()
    self.name = name
  }
}

extension QueryTaskInfo: CustomStringConvertible {
  public var description: String {
    "[\(name ?? "Unnamed QueryTask")](ID: \(id.debugDescription))"
  }
}

extension QueryContext {
  public var queryRunningTaskInfo: QueryTaskInfo? {
    get { self[QueryTaskInfoKey.self] }
    set { self[QueryTaskInfoKey.self] = newValue }
  }

  private enum QueryTaskInfoKey: Key {
    static var defaultValue: QueryTaskInfo? { nil }
  }
}

// MARK: - Warnings

extension QueryCoreWarning {
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
