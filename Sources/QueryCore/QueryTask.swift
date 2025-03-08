import ConcurrencyExtras
import Foundation

// MARK: - _QueryTask

private protocol _QueryTask: Sendable, Identifiable {
  var id: QueryTaskID { get }

  var dependencies: [any _QueryTask] { get }

  func _runIfNeeded() async throws -> any Sendable

  func warnIfCyclesDetected(cyclicalIds: [QueryTaskID], visited: Set<QueryTaskID>)
}

// MARK: - QueryTask

public struct QueryTask<Value: Sendable>: _QueryTask {
  private typealias State = (task: Task<any Sendable, any Error>?, dependencies: [any _QueryTask])

  public let id: QueryTaskID
  public let context: QueryContext
  fileprivate var dependencies: [any _QueryTask] {
    self.box.inner.withLock { $0.dependencies }
  }
  private var work: @Sendable () async throws -> Value
  private let box: LockedBox<State>
}

extension QueryTask {
  public init(context: QueryContext, work: @escaping @Sendable () async throws -> Value) {
    self.context = context
    self.work = work
    self.box = LockedBox(value: (nil, []))
    self.id = .next()
  }
}

// MARK: - QueryTaskID

public struct QueryTaskID: Hashable, Sendable {
  private let number: Int
}

extension QueryTaskID {
  private static let counter = Lock(1)

  fileprivate static func next() -> Self {
    counter.withLock { counter in
      defer { counter += 1 }
      return Self(number: counter)
    }
  }
}

extension QueryTaskID: CustomDebugStringConvertible {
  public var debugDescription: String {
    "#\(self.number)"
  }
}

// MARK: - Task Dependencies

extension QueryTask {
  public func schedule<V: Sendable>(after task: QueryTask<V>) {
    self.withDependencies {
      $0.removeAll { $0.id == task.id }
      $0.append(task)
    }
  }

  public func schedule<V: Sendable>(after tasks: [QueryTask<V>]) {
    self.withDependencies {
      let ids = Set(tasks.map(\.id))
      $0.removeAll { ids.contains($0.id) }
      $0.append(contentsOf: tasks.removeFirstDuplicates(by: \.id))
    }
  }

  private func withDependencies(_ fn: (inout [any _QueryTask]) -> Void) {
    self.box.inner.withLock { fn(&$0.dependencies) }
    self.warnIfCyclesDetected(cyclicalIds: [self.id], visited: [self.id])
  }

  fileprivate func warnIfCyclesDetected(
    cyclicalIds: [QueryTaskID],
    visited: Set<QueryTaskID>
  ) {
    #if DEBUG
      for dependency in self.dependencies {
        if visited.contains(dependency.id) {
          reportWarning(.queryTaskCircularScheduling(ids: cyclicalIds + [dependency.id]))
        } else {
          dependency.warnIfCyclesDetected(
            cyclicalIds: cyclicalIds + [dependency.id],
            visited: visited.union([dependency.id])
          )
        }
      }
    #endif
  }
}

// MARK: - Run

extension QueryTask {
  public func runIfNeeded() async throws -> Value {
    try await self._runIfNeeded() as! Value
  }

  fileprivate func _runIfNeeded() async throws -> any Sendable {
    let task = self.box.inner.withLock { state in
      if let task = state.task {
        return task
      }
      let task = Task {
        await withTaskGroup(of: Void.self) { group in
          for dependency in self.dependencies {
            group.addTask { _ = try? await dependency._runIfNeeded() }
          }
        }
        return try await self.work() as any Sendable
      }
      state.task = task
      return task
    }
    return try await task.cancellableValue
  }
}

// MARK: - Map

extension QueryTask {
  func map<T: Sendable>(
    _ transform: @escaping @Sendable (any Sendable) throws -> T
  ) -> QueryTask<T> {
    QueryTask<T>(
      id: self.id,
      context: self.context,
      work: { try await transform(try self.work()) },
      box: self.box
    )
  }
}

// MARK: - Warning

extension QueryCoreWarning {
  public static func queryTaskCircularScheduling(ids: [QueryTaskID]) -> Self {
    Self(
      """
      Circular scheduling detected for tasks.

        Cycle:

        \(ids.map(\.debugDescription).joined(separator: " -> "))

      This will cause task starvation when running any of the tasks in this cycle.
      """
    )
  }
}
