import Foundation
import IdentifiedCollections

// MARK: - _MutationStateProtocol

public protocol _MutationStateProtocol<Arguments, Value>: OperationState
where StatusValue == Value, OperationValue == MutationOperationValue<Value> {
  associatedtype Arguments: Sendable
  associatedtype Value: Sendable

  var history: IdentifiedArrayOf<MutationState<Arguments, Value>.HistoryEntry> { get }
}

// MARK: - MutationState

/// A state type for ``MutationRequest``.
///
/// Mutation states allow you to view the history of attempts via ``history``. This can be useful
/// for implementing UI flows that prevent certain actions based on previous failed mutation
/// attempts, such as not allowing an input to a form if it was tried in a previous unsuccessful
/// attempt and much more.
///
/// > Warning: You should not call any of the `mutating` methods directly on this type, rather a
/// > ``OperationStore`` will call them at the appropriate time for you.
public struct MutationState<Arguments: Sendable, Value: Sendable> {
  public private(set) var valueUpdateCount = 0
  private var historyValueLastUpdatedAt: Date?
  public private(set) var errorUpdateCount = 0
  private var historyErrorLastUpdatedAt: Date?
  private var yielded: Yielded?
  public let initialValue: StateValue

  /// The history of this mutation.
  ///
  /// This array stores all ongoing and previous attempts of fetching a mutation. Each attempt is
  /// marked by a ``HistoryEntry`` that contains the ``OperationTask`` used by the attempt,
  /// and information on the outcome of the attempt such as its ``OperationStatus``.
  ///
  /// You can use the history to implement UI flows that block known invalid inputs, prevent users
  /// from performing actions after they're known to fail, and much more.
  public private(set) var history = IdentifiedArrayOf<HistoryEntry>()

  /// Creates a mutation state.
  ///
  /// - Parameter initialValue: The initial value of this state.
  public init(initialValue: StateValue = nil) {
    self.initialValue = initialValue
  }
}

// MARK: - OperationState

extension MutationState: _MutationStateProtocol {
  public typealias StateValue = Value?
  public typealias StatusValue = Value
  public typealias OperationValue = MutationOperationValue<Value>

  public var currentValue: StateValue {
    switch (self.history.last?.status, self.yielded) {
    case (let status?, nil):
      return status.resultValue
    case (nil, .success(let value, _)):
      return value
    case (let status?, .success(let value, let lastUpdatedAt)):
      guard let historyValueLastUpdatedAt else { return value }
      return historyValueLastUpdatedAt > lastUpdatedAt ? status.resultValue : value
    case (nil, nil):
      return self.initialValue
    default:
      return nil
    }
  }

  public var valueLastUpdatedAt: Date? {
    switch (self.historyValueLastUpdatedAt, self.yielded) {
    case (let valueLastUpdatedAt?, nil):
      return valueLastUpdatedAt
    case (nil, .success(_, let lastUpdatedAt)):
      return lastUpdatedAt
    case (let valueLastUpdatedAt?, .success(_, let lastUpdatedAt)):
      return max(valueLastUpdatedAt, lastUpdatedAt)
    default:
      return nil
    }
  }

  public var error: (any Error)? {
    switch (self.history.last?.status.resultError, self.yielded) {
    case (let historyError?, nil):
      return historyError
    case (nil, .failure(let error, _)):
      return error
    case (let historyError?, .failure(let error, let lastUpdatedAt)):
      guard let historyErrorLastUpdatedAt else { return error }
      return historyErrorLastUpdatedAt > lastUpdatedAt ? historyError : error
    default:
      return nil
    }
  }

  public var errorLastUpdatedAt: Date? {
    switch (self.historyErrorLastUpdatedAt, self.yielded) {
    case (let errorLastUpdatedAt?, nil):
      return errorLastUpdatedAt
    case (nil, .failure(_, let lastUpdatedAt)):
      return lastUpdatedAt
    case (let errorLastUpdatedAt?, .failure(_, let lastUpdatedAt)):
      return max(errorLastUpdatedAt, lastUpdatedAt)
    default:
      return nil
    }
  }

  public var isLoading: Bool {
    self.history.last?.status.isLoading ?? false
  }

  public mutating func scheduleFetchTask(_ task: inout OperationTask<OperationValue, any Error>) {
    let args = task.context.mutationArgs(as: Arguments.self) ?? self.history.last?.arguments
    guard let args else {
      reportWarning(.mutationWithNoArgumentsOrHistory)
      return
    }
    task.context.mutationValues.arguments = args
    self.history.append(HistoryEntry(task: task, args: args))
    if self.history.count > task.context.mutationValues.maxHistoryLength {
      self.history.removeFirst()
    }
  }

  public mutating func reset(using context: OperationContext) -> ResetEffect {
    let tasksToCancel = self.history.map(\.baseTask)
    self = Self(initialValue: self.initialValue)
    return ResetEffect(tasksToCancel: tasksToCancel)
  }

  public mutating func update(
    with result: Result<Value?, any Error>,
    using context: OperationContext
  ) {
    switch result {
    case .success(let value):
      self.yielded = .success(value, context.operationClock.now())
      self.valueUpdateCount += 1
    case .failure(let error):
      self.yielded = .failure(error, context.operationClock.now())
      self.errorUpdateCount += 1
    }
  }

  public mutating func update(
    with result: Result<OperationValue, any Error>,
    for task: OperationTask<OperationValue, any Error>
  ) {
    self.history[id: task.id]?.update(with: result.map(\.returnValue))
    guard let last = self.history.last, last.task.id == task.id else { return }
    switch result {
    case .success:
      self.valueUpdateCount += 1
      self.historyValueLastUpdatedAt = last.lastUpdatedAt
    case .failure:
      self.errorUpdateCount += 1
      self.historyErrorLastUpdatedAt = last.lastUpdatedAt
    }
  }

  public mutating func finishFetchTask(_ task: OperationTask<OperationValue, any Error>) {
    self.history[id: task.id]?.finish()
  }
}

// MARK: - History Entry

extension MutationState {
  /// An entry of history for a ``MutationState``.
  public struct HistoryEntry: Sendable {
    /// The arguments passed to the mutation attempt represented by this entry.
    public let arguments: Arguments

    /// The `Date` of when this entry was added.
    public let startDate: Date

    /// The current and ongoing result of the mutation attempt represented by this entry.
    public private(set) var currentResult: Result<Value, any Error>?

    /// The date this entry was last modified.
    public private(set) var lastUpdatedAt: Date?

    /// The current ``OperationStatus`` of the mutation attempt represented by this entry.
    public private(set) var status: OperationStatus<StatusValue, any Error>

    /// The ``OperationTask`` for this entry.
    public var task: OperationTask<Value, any Error> {
      self.baseTask.map(\.returnValue)
    }

    fileprivate let baseTask: OperationTask<OperationValue, any Error>

    fileprivate init(task: OperationTask<OperationValue, any Error>, args: Arguments) {
      self.baseTask = task
      self.arguments = args
      self.startDate = task.context.operationClock.now()
      self.lastUpdatedAt = nil
      self.status = .loading
    }

    fileprivate mutating func update(with result: Result<Value, any Error>) {
      self.currentResult = result
      self.lastUpdatedAt = self.task.context.operationClock.now()
    }

    fileprivate mutating func finish() {
      if let currentResult {
        self.status = .result(currentResult)
      }
    }
  }
}

extension MutationState.HistoryEntry: Identifiable {
  public var id: OperationTaskIdentifier {
    self.task.id
  }
}

// MARK: - DefaultableOperationState

extension MutationState: DefaultableOperationState {
  public typealias DefaultStateValue = Value

  public func defaultValue(
    for value: StateValue,
    using defaultValue: DefaultStateValue
  ) -> DefaultStateValue {
    value ?? defaultValue
  }

  public func stateValue(for defaultStateValue: DefaultStateValue) -> StateValue {
    defaultStateValue
  }
}

// MARK: - DefaultOperationState

extension DefaultOperationState: _MutationStateProtocol
where Base: _MutationStateProtocol {
  public typealias Arguments = Base.Arguments
  public typealias Value = Base.Value

  public var history: IdentifiedArrayOf<MutationState<Arguments, Value>.HistoryEntry> {
    self.base.history
  }
}

// MARK: - Initial State

extension DefaultOperation where Operation: MutationRequest {
  package var initialState: State {
    State(MutationState(), defaultValue: self.defaultValue)
  }
}

// MARK: - Yielded

extension MutationState {
  private enum Yielded {
    case success(StateValue, Date)
    case failure(any Error, Date)
  }
}

// MARK: - Warnings

extension OperationWarning {
  public static let mutationWithNoArgumentsOrHistory = OperationWarning(
    """
    The latest mutation attempt was retried, but the retried mutation has no history.

    Calling `fetch` or `retryLatest` on a `OperationStore` that uses a mutation will retry the latest \
    mutation attempt in the history (ie. recalling `mutate`, but with the same arguments), but \
    this is impossible if there is no history for the mutation.

    Make sure to call `mutate` on the store first before calling `fetch` on the `OperationStore` \
    instance, or before calling `retryLatest` on the `MutationStore`.
    """
  )
}
