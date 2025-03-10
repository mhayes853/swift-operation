import Foundation
import IdentifiedCollections

// MARK: - MutationState

public struct MutationState<Arguments: Sendable, Value: Sendable> {
  public private(set) var currentValue: StateValue
  public let initialValue: StateValue
  public private(set) var valueUpdateCount = 0
  public private(set) var valueLastUpdatedAt: Date?
  public private(set) var isLoading = false
  public private(set) var error: (any Error)?
  public private(set) var errorUpdateCount = 0
  public private(set) var errorLastUpdatedAt: Date?
  public private(set) var history = IdentifiedArrayOf<HistoryEntry>()
}

extension MutationState {
  init() {
    self.currentValue = nil
    self.initialValue = nil
  }
}

// MARK: - QueryStateProtocol

extension MutationState: QueryStateProtocol {
  public typealias StateValue = Value?
  public typealias StatusValue = Value
  public typealias QueryValue = Value

  public mutating func fetchTaskStarted(_ task: QueryTask<Value>) -> QueryTask<Value> {
    self.isLoading = true
    self.history.append(HistoryEntry(task: task))
    return task
  }

  public mutating func fetchTaskEnded(
    _ task: QueryTask<Value>,
    with result: Result<Value, any Error>
  ) {
    let taskId = MutationTaskID(inner: task.id)
    self.history[id: taskId]?.finish(with: result)
    switch result {
    case let .success(value):
      self.currentValue = value
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = task.context.queryClock.now()
      self.error = nil
      self.isLoading = false
    case let .failure(error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = task.context.queryClock.now()
      self.isLoading = false
    }
  }
}

// MARK: - History Entry

extension MutationState {
  public struct HistoryEntry: Sendable {
    public let task: MutationTask<Value>
    public let arguments: Arguments
    public let startDate: Date
    public private(set) var finishDate: Date?
    public private(set) var status: QueryStatus<StatusValue>
  }
}

extension MutationState.HistoryEntry {
  fileprivate init(task: QueryTask<Value>) {
    self.task = MutationTask(inner: task)
    self.arguments = task.context.mutationValues?.arguments as! Arguments
    self.startDate = task.context.queryClock.now()
    self.finishDate = nil
    self.status = .loading
  }
}

extension MutationState.HistoryEntry {
  fileprivate mutating func finish(with result: Result<Value, any Error>) {
    self.finishDate = self.task.context.queryClock.now()
    self.status = .result(result)
  }
}

extension MutationState.HistoryEntry: Identifiable {
  public var id: MutationTaskID {
    self.task.id
  }
}
