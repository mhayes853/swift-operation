import Foundation
import IdentifiedCollections

// MARK: - QueryState

/// A state type used for ``QueryRequest``.
///
/// This state type is the default state type for your queries, though ``InfiniteQueryRequest``
/// and ``MutationRequest`` use ``InfiniteQueryState`` and ``MutationState`` respectively as their
/// state types.
///
/// You can only create instances of this state with an initial value that must have the same base
/// type as `QueryValue`. A nil value for ``currentValue`` indicates that the query has not yet
/// fetched any data, or has been yielded any value.
///
/// You can also access all active ``QueryTask`` instances on this state through the
/// ``activeTasks`` property. Tasks are removed from `activeTasks` when ``finishFetchTask(_:)`` is
/// called by a ``QueryStore``.
///
/// > Warning: You should not call any of the `mutating` methods directly on this type, rather a
/// > ``QueryStore`` will call them at the appropriate time for you.
public struct QueryState<StateValue: Sendable, QueryValue: Sendable> {
  public private(set) var currentValue: StateValue
  public let initialValue: StateValue
  public private(set) var valueUpdateCount = 0
  public private(set) var valueLastUpdatedAt: Date?
  public private(set) var error: (any Error)?
  public private(set) var errorUpdateCount = 0
  public private(set) var errorLastUpdatedAt: Date?

  /// The active ``QueryTask`` instances held by this state.
  public private(set) var activeTasks = IdentifiedArrayOf<QueryTask<QueryValue>>()

  /// Creates a query state.
  ///
  /// - Parameter initialValue: The initial value of the state.
  public init(initialValue: StateValue) where StateValue == QueryValue? {
    self.init(_initialValue: initialValue)
  }

  /// Creates a query state.
  ///
  /// - Parameter initialValue: The initial value of the state.
  public init(initialValue: StateValue) where StateValue == QueryValue {
    self.init(_initialValue: initialValue)
  }

  private init(_initialValue: StateValue) {
    self.currentValue = _initialValue
    self.initialValue = _initialValue
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
    self = Self(_initialValue: self.initialValue)
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
    self.update(with: result.map { $0 as! StateValue }, using: task.context)
  }

  public mutating func finishFetchTask(_ task: QueryTask<QueryValue>) {
    self.activeTasks.remove(id: task.id)
  }
}
