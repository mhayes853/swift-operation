import Foundation

// MARK: - QueryStateProtocol

public protocol QueryStateProtocol<StateValue, QueryValue>: Sendable {
  associatedtype StateValue: Sendable
  associatedtype QueryValue: Sendable

  var currentValue: StateValue { get set }
  var initialValue: StateValue { get set }
  var valueUpdateCount: Int { get set }
  var valueLastUpdatedAt: Date? { get set }
  var isLoading: Bool { get set }
  var error: (any Error)? { get set }
  var errorUpdateCount: Int { get set }
  var errorLastUpdatedAt: Date? { get set }
  var fetchTask: Task<any Sendable, any Error>? { get set }

  func casted<NewValue: Sendable, NewQueryValue: Sendable>(
    to newValue: NewValue.Type,
    newQueryValue: NewQueryValue.Type
  ) -> (any QueryStateProtocol)?

  init(initialValue: StateValue)
}

// MARK: - QueryState

public struct QueryState<StateValue: Sendable, QueryValue: Sendable>: QueryStateProtocol {
  public var currentValue: StateValue
  public var initialValue: StateValue
  public var valueUpdateCount = 0
  public var valueLastUpdatedAt: Date?
  public var isLoading = false
  public var error: (any Error)?
  public var errorUpdateCount = 0
  public var errorLastUpdatedAt: Date?
  public var fetchTask: Task<any Sendable, any Error>?
}

extension QueryState {
  public init(initialValue: StateValue) {
    self.currentValue = initialValue
    self.initialValue = initialValue
  }
}

// MARK: - Fetch Task

extension QueryStateProtocol {
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

  mutating func endFetchTask(with value: StateValue) {
    self.currentValue = value
    self.valueUpdateCount += 1
    self.valueLastUpdatedAt = Date()
    self.error = nil
    self.isLoading = false
    self.fetchTask = nil
  }

  mutating func finishFetchTask(with error: any Error) {
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
