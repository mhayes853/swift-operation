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
    let args = task.context.mutationArgs(as: Arguments.self) ?? self.history.last?.arguments
    guard let args else {
      reportWarning(.mutationWithNoArgumentsOrHistory)
      return task
    }
    var task = task
    task.context.mutationValues = MutationContextValues(arguments: args)
    self.history.append(HistoryEntry(task: task, args: args))
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

    fileprivate init(task: QueryTask<Value>, args: Arguments) {
      self.task = MutationTask(inner: task)
      self.arguments = args
      self.startDate = task.context.queryClock.now()
      self.finishDate = nil
      self.status = .loading
    }
  }
}

extension MutationState.HistoryEntry: Identifiable {
  public var id: MutationTaskID {
    self.task.id
  }
}

extension MutationState.HistoryEntry {
  fileprivate mutating func finish(with result: Result<Value, any Error>) {
    self.finishDate = self.task.context.queryClock.now()
    self.status = .result(result)
  }
}

// MARK: - Warnings

extension QueryCoreWarning {
  public static let mutationWithNoArgumentsOrHistory = QueryCoreWarning(
    """
    A mutation was started by a base QueryStore instance, but no history for the mutation exists.

    Calling `fetch` on a QueryStore that uses a mutation will retry the latest mutation attempt in
    the history (ie. recalling `mutate`, but with the same arguments), but this is impossible if
    there is no history for the mutation.

    Make sure to call `mutate` on a `MutationStore` instance first before calling `fetch` on the
    `QueryStore` instance, and ensure that the MutationStore uses the same QueryStore.
    """
  )
}
