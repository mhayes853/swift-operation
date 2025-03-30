import Foundation
import IdentifiedCollections

// MARK: - _MutationStateProtocol

public protocol _MutationStateProtocol<Arguments, Value>: QueryStateProtocol
where StateValue == Value?, StatusValue == Value, QueryValue == Value {
  associatedtype Arguments: Sendable
  associatedtype Value: Sendable
}

// MARK: - MutationState

public struct MutationState<Arguments: Sendable, Value: Sendable> {
  public private(set) var valueUpdateCount = 0
  private var historyValueLastUpdatedAt: Date?
  public private(set) var errorUpdateCount = 0
  private var historyErrorLastUpdatedAt: Date?
  public private(set) var history = IdentifiedArrayOf<HistoryEntry>()
  private var yielded: Yielded?

  public init() {}
}

// MARK: - QueryStateProtocol

extension MutationState: _MutationStateProtocol {
  public typealias StateValue = Value?
  public typealias StatusValue = Value
  public typealias QueryValue = Value

  public var initialValue: StateValue { nil }

  public var currentValue: StateValue {
    switch (self.history.last?.status.resultValue, self.yielded) {
    case let (historyValue?, nil):
      return historyValue
    case let (nil, .success(value, _)):
      return value
    case let (historyValue?, .success(value, lastUpdatedAt)):
      guard let historyValueLastUpdatedAt else { return value }
      return historyValueLastUpdatedAt > lastUpdatedAt ? historyValue : value
    default:
      return nil
    }
  }

  public var valueLastUpdatedAt: Date? {
    switch (self.historyValueLastUpdatedAt, self.yielded) {
    case let (valueLastUpdatedAt?, nil):
      return valueLastUpdatedAt
    case let (nil, .success(_, lastUpdatedAt)):
      return lastUpdatedAt
    case let (valueLastUpdatedAt?, .success(_, lastUpdatedAt)):
      return max(valueLastUpdatedAt, lastUpdatedAt)
    default:
      return nil
    }
  }

  public var error: (any Error)? {
    switch (self.history.last?.status.resultError, self.yielded) {
    case let (historyError?, nil):
      return historyError
    case let (nil, .failure(error, _)):
      return error
    case let (historyError?, .failure(error, lastUpdatedAt)):
      guard let historyErrorLastUpdatedAt else { return error }
      return historyErrorLastUpdatedAt > lastUpdatedAt ? historyError : error
    default:
      return nil
    }
  }

  public var errorLastUpdatedAt: Date? {
    switch (self.historyErrorLastUpdatedAt, self.yielded) {
    case let (errorLastUpdatedAt?, nil):
      return errorLastUpdatedAt
    case let (nil, .failure(_, lastUpdatedAt)):
      return lastUpdatedAt
    case let (errorLastUpdatedAt?, .failure(_, lastUpdatedAt)):
      return max(errorLastUpdatedAt, lastUpdatedAt)
    default:
      return nil
    }
  }

  public var isLoading: Bool {
    self.history.last?.status.isLoading ?? false
  }

  public mutating func scheduleFetchTask(_ task: inout QueryTask<Value>) {
    let args =
      task.configuration.context.mutationArgs(as: Arguments.self) ?? self.history.last?.arguments
    guard let args else {
      reportWarning(.mutationWithNoArgumentsOrHistory)
      return
    }
    task.configuration.context.mutationValues = MutationContextValues(arguments: args)
    self.history.append(HistoryEntry(task: task, args: args))
  }

  public mutating func reset(using context: QueryContext) {
    for entry in self.history {
      entry.task.cancel()
    }
    self = Self()
  }

  public mutating func update(
    with result: Result<Value?, any Error>,
    using context: QueryContext
  ) {
    switch result {
    case let .success(value):
      self.yielded = .success(value, context.queryClock.now())
      self.valueUpdateCount += 1
    case let .failure(error):
      self.yielded = .failure(error, context.queryClock.now())
      self.errorUpdateCount += 1
    }
  }

  public mutating func update(
    with result: Result<Value, any Error>,
    for task: QueryTask<Value>
  ) {
    self.history[id: task.id]?.update(with: result)
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

  public mutating func finishFetchTask(_ task: QueryTask<Value>) {
    self.history[id: task.id]?.finish()
  }
}

// MARK: - History Entry

extension MutationState {
  public struct HistoryEntry: Sendable {
    public let task: QueryTask<Value>
    public let arguments: Arguments
    public let startDate: Date
    public private(set) var currentResult: Result<Value, any Error>?
    public private(set) var lastUpdatedAt: Date?
    public private(set) var status: QueryStatus<StatusValue>

    fileprivate init(task: QueryTask<Value>, args: Arguments) {
      self.task = task
      self.arguments = args
      self.startDate = task.configuration.context.queryClock.now()
      self.lastUpdatedAt = nil
      self.status = .loading
    }
  }
}

extension MutationState.HistoryEntry: Identifiable {
  public var id: QueryTaskIdentifier {
    self.task.id
  }
}

extension MutationState.HistoryEntry {
  fileprivate mutating func update(with result: Result<Value, any Error>) {
    self.currentResult = result
    self.lastUpdatedAt = self.task.configuration.context.queryClock.now()
  }

  fileprivate mutating func finish() {
    if let currentResult {
      self.status = .result(currentResult)
    }
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

extension QueryCoreWarning {
  public static let mutationWithNoArgumentsOrHistory = QueryCoreWarning(
    """
    The latest mutation attempt was retried, but the retried mutation has no history.

    Calling `fetch` on a QueryStore, or `retryLatest` on a `MutationStore` that uses a mutation
    will retry the latest mutation attempt in the history (ie. recalling `mutate`, but with the
    same arguments), but this is impossible if there is no history for the mutation.

    Make sure to call `mutate` on a `MutationStore` instance first before calling `fetch` on the
    `QueryStore` instance, or before calling `retryLatest` on the `MutationStore`.
    """
  )
}
