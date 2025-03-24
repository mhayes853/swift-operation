import Foundation
import IdentifiedCollections

// MARK: - QueryState

public struct QueryState<StateValue: Sendable, QueryValue: Sendable> {
  public private(set) var currentValue: StateValue
  public let initialValue: StateValue
  public private(set) var valueUpdateCount = 0
  public private(set) var valueLastUpdatedAt: Date?
  public private(set) var error: (any Error)?
  public private(set) var errorUpdateCount = 0
  public private(set) var errorLastUpdatedAt: Date?
  public private(set) var activeTasks = IdentifiedArrayOf<QueryTask<QueryValue>>()

  public init(initialValue: StateValue) where StateValue == QueryValue? {
    self.currentValue = initialValue
    self.initialValue = initialValue
  }

  public init(initialValue: StateValue) where StateValue == QueryValue {
    self.currentValue = initialValue
    self.initialValue = initialValue
  }
}

// MARK: - Fetch Task

extension QueryState: QueryStateProtocol {
  public typealias StatusValue = QueryValue

  public var isLoading: Bool {
    !self.activeTasks.isEmpty
  }

  public mutating func scheduleFetchTask(_ task: inout QueryTask<QueryValue>) {
    self.activeTasks.append(task)
  }

  public mutating func reset(using context: QueryContext) {
    for task in self.activeTasks {
      task.cancel()
    }
    self.activeTasks.removeAll()
    self.currentValue = self.initialValue
    self.valueUpdateCount = 0
    self.valueLastUpdatedAt = nil
    self.error = nil
    self.errorUpdateCount = 0
    self.errorLastUpdatedAt = nil
  }

  public mutating func update(
    with result: Result<StateValue, any Error>,
    using context: QueryContext
  ) {
    switch result {
    case let .success(value):
      self.currentValue = value
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = context.queryClock.now()
      self.error = nil
    case let .failure(error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = context.queryClock.now()
    }
  }

  public mutating func update(
    with result: Result<QueryValue, any Error>,
    for task: QueryTask<QueryValue>
  ) {
    self.update(with: result.map { $0 as! StateValue }, using: task.configuration.context)
  }

  public mutating func finishFetchTask(_ task: QueryTask<QueryValue>) {
    self.activeTasks.remove(id: task.id)
  }
}
