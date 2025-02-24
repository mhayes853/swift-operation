import Foundation

// MARK: - QueryState

public struct QueryState<Value: Sendable>: Sendable {
  public private(set) var currentValue: Value
  public let initialValue: Value
  public private(set) var valueUpdateCount = 0
  public private(set) var valueLastUpdatedAt: Date?
  public private(set) var isLoading = false
  public private(set) var error: (any Error)?
  public private(set) var errorUpdateCount = 0
  public private(set) var errorLastUpdatedAt: Date?
  private var fetchTask: Task<any Sendable, any Error>?
}

extension QueryState {
  init(initialValue: Value) {
    self.currentValue = initialValue
    self.initialValue = initialValue
  }
}

// MARK: - Fetch Task

extension QueryState {
  mutating func startFetchTask(
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

  mutating func endFetchTack(with value: Value) {
    self.currentValue = value
    self.valueUpdateCount += 1
    self.valueLastUpdatedAt = Date()
    self.error = nil
    self.isLoading = false
    self.fetchTask = nil
  }

  mutating func endFetchTask(with error: any Error) {
    self.error = error
    self.errorUpdateCount += 1
    self.errorLastUpdatedAt = Date()
    self.isLoading = false
    self.fetchTask = nil
  }
}

// MARK: - Casting

extension QueryState {
  func unsafeCasted<V>(to type: V.Type) -> QueryState<V> {
    QueryState<V>(
      currentValue: self.currentValue as! V,
      initialValue: self.initialValue as! V,
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
