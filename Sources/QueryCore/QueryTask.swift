import ConcurrencyExtras
import Foundation

// MARK: - QueryTask

public struct QueryTask<Value: Sendable>: Sendable {
  public let context: QueryContext
  private var dependencies = [Self]()
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
  public mutating func depend(on task: Self) {
    self.dependencies.append(task)
  }

  public mutating func depend(on tasks: [Self]) {
    self.dependencies.append(contentsOf: tasks)
  }

  public func depending(on task: Self) -> Self {
    var new = self
    new.depend(on: task)
    return new
  }

  public func depending(on tasks: [Self]) -> Self {
    var new = self
    new.depend(on: tasks)
    return new
  }
}

// MARK: - Run

extension QueryTask {
  public func run() async throws -> Value {
    let task = self.box.inner.withLock { task in
      if let task {
        return task
      }
      let newTask = Task {
        // TODO: - Does this need a TaskGroup?
        for dependency in self.dependencies {
          _ = try await dependency.run()
        }
        return try await self.work() as any Sendable
      }
      task = newTask
      return newTask
    }
    return try await task.cancellableValue as! Value
  }
}

// MARK: - Map

extension QueryTask {
  func map<T: Sendable>(
    _ transform: @escaping @Sendable (Value) throws -> T
  ) -> QueryTask<T> {
    QueryTask<T>(
      context: self.context,
      dependencies: self.dependencies.map { $0.map(transform) },
      work: { try await transform(try self.work()) },
      box: self.box
    )
  }
}
