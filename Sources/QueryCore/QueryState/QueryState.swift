import Foundation

// MARK: - QueryState

public struct QueryState<StateValue: Sendable, QueryValue: Sendable>: QueryStateProtocol {
  public private(set) var currentValue: StateValue
  public private(set) var initialValue: StateValue
  public private(set) var valueUpdateCount = 0
  public private(set) var valueLastUpdatedAt: Date?
  public private(set) var isLoading = false
  public private(set) var error: (any Error)?
  public private(set) var errorUpdateCount = 0
  public private(set) var errorLastUpdatedAt: Date?
  public private(set) var fetchTask: Task<any Sendable, any Error>?
}

extension QueryState {
  public init(initialValue: StateValue) {
    self.currentValue = initialValue
    self.initialValue = initialValue
  }
}

// MARK: - Fetch Task

extension QueryState {
  public mutating func startFetchTask(
    for fn: @Sendable @escaping () async throws -> any Sendable
  ) -> Task<any Sendable, any Error> {
    if let task = self.fetchTask {
      return task
    }
    self.isLoading = true
    let task = Task { try await fn() }
    self.fetchTask = task
    return task
  }

  public mutating func endFetchTask(with value: StateValue) {
    self.currentValue = value
    self.valueUpdateCount += 1
    self.valueLastUpdatedAt = Date()
    self.error = nil
    self.isLoading = false
    self.fetchTask = nil
  }

  public mutating func finishFetchTask(with error: any Error) {
    self.error = error
    self.errorUpdateCount += 1
    self.errorLastUpdatedAt = Date()
    self.isLoading = false
    self.fetchTask = nil
  }
}

// MARK: - Casting

extension QueryState {
  public func casted<NewValue: Sendable, NewQueryValue: Sendable>(
    to newValue: NewValue.Type,
    newQueryValue: NewQueryValue.Type
  ) -> (any QueryStateProtocol)? {
    guard let cv = self.currentValue as? NewValue else { return nil }
    guard let iv = self.initialValue as? NewValue else { return nil }
    return QueryState<NewValue, NewQueryValue>(
      currentValue: cv,
      initialValue: iv,
      valueUpdateCount: self.valueUpdateCount,
      valueLastUpdatedAt: self.valueLastUpdatedAt,
      isLoading: self.isLoading,
      error: self.error,
      errorUpdateCount: self.errorUpdateCount,
      errorLastUpdatedAt: self.errorLastUpdatedAt,
      fetchTask: self.fetchTask
    )
  }
}
