import Foundation

// MARK: - QueryState

public struct QueryState<StateValue: Sendable, QueryValue: Sendable> {
  public private(set) var currentValue: StateValue
  public let initialValue: StateValue
  public private(set) var valueUpdateCount = 0
  public private(set) var valueLastUpdatedAt: Date?
  public private(set) var isLoading = false
  public private(set) var error: (any Error)?
  public private(set) var errorUpdateCount = 0
  public private(set) var errorLastUpdatedAt: Date?
  private var fetchTask: QueryTask<QueryValue>?
}

extension QueryState {
  public init(initialValue: StateValue) {
    self.currentValue = initialValue
    self.initialValue = initialValue
  }
}

// MARK: - Fetch Task

extension QueryState: QueryStateProtocol {
  public typealias StatusValue = QueryValue

  public mutating func startFetchTask(_ task: QueryTask<QueryValue>) -> QueryTask<QueryValue> {
    if let task = self.fetchTask {
      return task
    }
    self.isLoading = true
    self.fetchTask = task
    return task
  }

  public mutating func endFetchTask(
    _ task: QueryTask<QueryValue>,
    with result: Result<QueryValue, any Error>
  ) {
    switch result {
    case let .success(value):
      self.currentValue = value as! StateValue
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = task.context.queryClock.now()
      self.error = nil
      self.isLoading = false
      self.fetchTask = nil
    case let .failure(error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = task.context.queryClock.now()
      self.isLoading = false
      self.fetchTask = nil
    }
  }
}
