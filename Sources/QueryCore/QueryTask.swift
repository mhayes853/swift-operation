import ConcurrencyExtras
import Foundation

// MARK: - _QueryTask

private protocol _QueryTask: Sendable {
  func _runIfNotRunning() async throws -> any Sendable

  func map<T: Sendable>(
    _ transform: @escaping @Sendable (any Sendable) throws -> T
  ) -> QueryTask<T>
}

// MARK: - QueryTask

public struct QueryTask<Value: Sendable>: _QueryTask {
  public let context: QueryContext
  private var dependencies = [any _QueryTask]()
  private var work: @Sendable () async throws -> Value
  private let box: LockedBox<Task<any Sendable, any Error>?>
}

extension QueryTask {
  public init(context: QueryContext, work: @escaping @Sendable () async throws -> Value) {
    self.context = context
    self.work = work
    self.box = LockedBox(value: nil)
  }
}

// MARK: - Task Dependencies

extension QueryTask {
  public mutating func depend<V: Sendable>(on task: QueryTask<V>) {
    self.dependencies.append(task)
  }

  public mutating func depend<V: Sendable>(on tasks: [QueryTask<V>]) {
    self.dependencies.append(contentsOf: tasks)
  }

  public func depending<V: Sendable>(on task: QueryTask<V>) -> Self {
    var new = self
    new.depend(on: task)
    return new
  }

  public func depending<V: Sendable>(on tasks: [QueryTask<V>]) -> Self {
    var new = self
    new.depend(on: tasks)
    return new
  }
}

// MARK: - Run

extension QueryTask {
  public func runIfNotRunning() async throws -> Value {
    try await self._runIfNotRunning() as! Value
  }

  fileprivate func _runIfNotRunning() async throws -> any Sendable {
    let task = self.box.inner.withLock { task in
      if let task {
        return task
      }
      let newTask = Task {
        // TODO: - Does this need a TaskGroup?
        for dependency in self.dependencies {
          _ = try await dependency._runIfNotRunning()
        }
        return try await self.work() as any Sendable
      }
      task = newTask
      return newTask
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
      context: self.context,
      dependencies: self.dependencies.map { task in
        task.map { try transform($0 as any Sendable) }
      },
      work: { try await transform(try self.work()) },
      box: self.box
    )
  }
}
