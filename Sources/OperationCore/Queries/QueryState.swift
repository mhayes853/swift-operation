import Foundation
import IdentifiedCollections

// MARK: - QueryStateProtocol

public protocol _QueryStateProtocol<Value, Failure>: OperationState
where OperationValue == Value, StatusValue == Value {
  associatedtype Value: Sendable

  var activeTasks: IdentifiedArrayOf<OperationTask<Value, Failure>> { get }
}

// MARK: - QueryState

/// A state type used for ``QueryRequest``.
///
/// This state type is the default state type for your queries, though ``PaginatedRequest``
/// and ``MutationRequest`` use ``PaginatedState`` and ``MutationState`` respectively as their
/// state types.
///
/// You can only create instances of this state with an initial value that must have the same base
/// type as `QueryValue`. A nil value for ``currentValue`` indicates that the query has not yet
/// fetched any data, or has been yielded any value.
///
/// You can also access all active ``OperationTask`` instances on this state through the
/// ``activeTasks`` property. Tasks are removed from `activeTasks` when ``finishFetchTask(_:)`` is
/// called by a ``OperationStore``.
///
/// > Warning: You should not call any of the `mutating` methods directly on this type, rather a
/// > ``OperationStore`` will call them at the appropriate time for you.
public struct QueryState<Value: Sendable, Failure: Error>: Sendable {
  public private(set) var currentValue: Value?
  public let initialValue: Value?
  public private(set) var valueUpdateCount = 0
  public private(set) var valueLastUpdatedAt: Date?
  public private(set) var error: Failure?
  public private(set) var errorUpdateCount = 0
  public private(set) var errorLastUpdatedAt: Date?

  /// The active ``OperationTask`` instances held by this state.
  public private(set) var activeTasks = IdentifiedArrayOf<OperationTask<Value, Failure>>()

  /// Creates a query state.
  ///
  /// - Parameter initialValue: The initial value of the state.
  public init(initialValue: Value?) {
    self.init(_initialValue: initialValue)
  }

  private init(_initialValue: StateValue) {
    self.currentValue = _initialValue
    self.initialValue = _initialValue
  }
}

// MARK: - Fetch Task

extension QueryState: _QueryStateProtocol {
  public typealias StatusValue = Value

  public var isLoading: Bool {
    !self.activeTasks.isEmpty
  }

  public mutating func scheduleFetchTask(_ task: inout OperationTask<Value, Failure>) {
    self.activeTasks.append(task)
  }

  public mutating func reset(using context: OperationContext) -> ResetEffect {
    let tasksToCancel = self.activeTasks
    self = Self(_initialValue: self.initialValue)
    return ResetEffect(tasksToCancel: tasksToCancel)
  }

  public mutating func update(
    with result: Result<Value?, Failure>,
    using context: OperationContext
  ) {
    switch result {
    case .success(let value):
      self.currentValue = value
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = context.operationClock.now()
      self.error = nil
    case .failure(let error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = context.operationClock.now()
    }
  }

  public mutating func update(
    with result: Result<Value, Failure>,
    for task: OperationTask<Value, Failure>
  ) {
    self.update(with: result.map { $0 as Value? }, using: task.context)
  }

  public mutating func finishFetchTask(_ task: OperationTask<Value, Failure>) {
    self.activeTasks.remove(id: task.id)
  }
}

// MARK: - DefaultableOperationState

extension QueryState: DefaultableOperationState {
  public typealias DefaultStateValue = Value

  public func defaultValue(for value: Value?, using defaultValue: Value) -> Value {
    value ?? defaultValue
  }

  public func stateValue(for defaultStateValue: Value) -> Value? {
    defaultStateValue
  }
}

// MARK: - DefaultOperationState

extension DefaultOperationState: _QueryStateProtocol where Base: _QueryStateProtocol {
  public var activeTasks: IdentifiedArrayOf<OperationTask<Base.Value, Base.Failure>> {
    self.base.activeTasks
  }
}

// MARK: - Initial State

extension DefaultStateOperation where Operation: QueryRequest {
  package var initialState: State {
    State(QueryState(initialValue: nil), defaultValue: self.defaultValue)
  }
}
