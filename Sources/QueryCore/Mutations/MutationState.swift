import Foundation
import IdentifiedCollections

// MARK: - MutationState

public struct MutationState<Arguments: Sendable, Value: Sendable> {
  public private(set) var valueUpdateCount = 0
  public private(set) var valueLastUpdatedAt: Date?
  public private(set) var errorUpdateCount = 0
  public private(set) var errorLastUpdatedAt: Date?
  public private(set) var history = IdentifiedArrayOf<HistoryEntry>()
}

// MARK: - QueryStateProtocol

extension MutationState: QueryStateProtocol {
  public typealias StateValue = Value?
  public typealias StatusValue = Value
  public typealias QueryValue = Value

  public var initialValue: StateValue { nil }

  public var currentValue: StateValue {
    self.history.last?.status.resultValue
  }

  public var error: (any Error)? {
    self.history.last?.status.resultError
  }

  public var isLoading: Bool {
    self.history.last?.status.isLoading ?? false
  }

  public mutating func fetchTaskStarted(_ task: QueryTask<Value>) -> QueryTask<Value> {
    self.history.append(HistoryEntry(task: task))
    return task
  }

  public mutating func fetchTaskEnded(
    _ task: QueryTask<Value>,
    with result: Result<Value, any Error>
  ) {
    let taskId = MutationTaskID(inner: task.id)
    self.history[id: taskId]?.finish(with: result)
    guard let last = self.history.last, last.task.id == taskId else { return }
    switch result {
    case .success:
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = last.finishDate
    case .failure:
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = last.finishDate
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
