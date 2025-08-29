import IdentifiedCollections

// MARK: - OperationStatus

/// An enum representing the current status of a query.
///
/// You generally don't create instances of this enum directly, and instead you can access it via
/// ``OperationState/status-5oj8d`` on your query's state.
public enum OperationStatus<Value: Sendable, Failure: Error>: Sendable {
  /// The query has never been fetched.
  case idle

  /// The query is currently fetching data.
  case loading

  /// The query has completed with a result.
  case result(Result<Value, Failure>)
}

// MARK: - Case Checking

extension OperationStatus {
  /// Whether or not the status is idle.
  public var isIdle: Bool {
    switch self {
    case .idle: true
    default: false
    }
  }

  /// Whether or not the status is loading.
  public var isLoading: Bool {
    switch self {
    case .loading: true
    default: false
    }
  }

  /// The result value, if the status indicates that the query finished successfully.
  public var resultValue: Value? {
    switch self {
    case .result(.success(let value)): value
    default: nil
    }
  }

  /// The result error, if the status indicates that the query finished unsuccessfully.
  public var resultError: Error? {
    switch self {
    case .result(.failure(let error)): error
    default: nil
    }
  }

  /// The result, if the status indicates that the query finished.
  public var result: Result<Value, Failure>? {
    switch self {
    case .result(let result): result
    default: nil
    }
  }

  /// Whether or not the query finished.
  public var isFinished: Bool {
    self.result != nil
  }

  /// Whether or not the query finished successfully.
  public var isSuccessful: Bool {
    self.resultValue != nil
  }

  /// Whether or not the query finished unsuccessfully.
  public var isFailure: Bool {
    self.resultError != nil
  }

  /// Whether or not the query finished unsuccessfully with a `CancellationError`.
  public var isCancelled: Bool {
    self.resultError is CancellationError
  }
}

// MARK: - Mapping

extension OperationStatus {
  /// Maps the success value of this status if it indicates that the query finished successfully.
  ///
  /// If this status isn't successful, then it is returned instead.
  ///
  /// ```swift
  /// let status = OperationStatus<Int>.result(.success(10))
  /// let status2: OperationStatus<String> = status.mapSuccess { String($0) }
  /// ```
  ///
  /// - Parameter transform: A function to transform the value into a new value.
  /// - Returns: A status with the newly transformed value.
  public func mapSuccess<NewValue: Sendable, E: Error>(
    _ transform: (Value) throws(E) -> NewValue
  ) throws(E) -> OperationStatus<NewValue, Failure> {
    switch self {
    case .result(.success(let value)): try .result(.success(transform(value)))
    case .result(.failure(let error)): .result(.failure(error))
    case .idle: .idle
    case .loading: .loading
    }
  }

  /// Transforms this status into another ``OperationStatus`` based on the success value of this status
  /// if one is present.
  ///
  /// If this status isn't successful, then it is returned instead.
  ///
  /// ```swift
  /// let status = OperationStatus<Int>.result(.success(10))
  /// let status2: OperationStatus<String> = status.flatMapSuccess {
  ///   .result(.success(String($0)))
  /// }
  /// ```
  ///
  /// - Parameter transform: A function to transform the value into a new status.
  /// - Returns: The status returned from `transform`, or the current status if it isn't successful.
  public func flatMapSuccess<NewValue: Sendable, E: Error>(
    _ transform: (Value) throws(E) -> OperationStatus<NewValue, Failure>
  ) throws(E) -> OperationStatus<NewValue, Failure> {
    switch self {
    case .result(.success(let value)): try transform(value)
    case .result(.failure(let error)): .result(.failure(error))
    case .idle: .idle
    case .loading: .loading
    }
  }
}

// MARK: - Protocols

extension OperationStatus: Hashable where Value: Hashable, Failure: Hashable {}
extension OperationStatus: Equatable where Value: Equatable, Failure: Equatable {}

// MARK: - OperationState

extension OperationState where StateValue == StatusValue {
  /// The current ``OperationStatus`` of this query.
  public var status: OperationStatus<StatusValue, Failure> {
    self.stateStatus
  }
}

extension OperationState where StateValue == StatusValue? {
  /// The current ``OperationStatus`` of this query.
  public var status: OperationStatus<StatusValue, Failure> {
    self.stateStatus.flatMapSuccess { value in
      if let value {
        return .result(.success(value))
      } else {
        return .idle
      }
    }
  }
}

extension OperationState {
  private var stateStatus: OperationStatus<StateValue, Failure> {
    if self.isLoading {
      return .loading
    } else if self.valueUpdateCount == 0 && self.errorUpdateCount == 0 {
      return .idle
    } else if self.hasMostRecentValueUpdate {
      return .result(.success(self.currentValue))
    } else if let error, !self.hasMostRecentValueUpdate {
      return .result(.failure(error))
    } else {
      return .idle
    }
  }

  private var hasMostRecentValueUpdate: Bool {
    guard let valueLastUpdatedAt else { return self.errorLastUpdatedAt == nil }
    guard let errorLastUpdatedAt else { return true }
    return valueLastUpdatedAt > errorLastUpdatedAt
  }
}
