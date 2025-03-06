import Foundation

// MARK: - MutationState

public struct MutationState<Value: Sendable> {
  public private(set) var currentValue: StateValue
  public let initialValue: StateValue
  public private(set) var valueUpdateCount = 0
  public private(set) var valueLastUpdatedAt: Date?
  public private(set) var isLoading = false
  public private(set) var error: (any Error)?
  public private(set) var errorUpdateCount = 0
  public private(set) var errorLastUpdatedAt: Date?
  private var fetchTask: Task<any Sendable, any Error>?
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

  public mutating func startFetchTask(
    in context: QueryContext,
    for fn: @escaping @Sendable () async throws -> any Sendable
  ) -> Task<any Sendable, any Error> {
    if let task = self.fetchTask {
      return task
    }
    self.isLoading = true
    let task = Task { try await fn() }
    self.fetchTask = task
    return task
  }

  public mutating func endFetchTask(
    in context: QueryContext,
    with result: Result<QueryValue, any Error>
  ) {
    switch result {
    case let .success(value):
      self.currentValue = value
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = context.queryClock.now()
      self.error = nil
      self.isLoading = false
      self.fetchTask = nil
    case let .failure(error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = context.queryClock.now()
      self.isLoading = false
      self.fetchTask = nil
    }
  }
}
