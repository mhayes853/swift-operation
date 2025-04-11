import IdentifiedCollections

// MARK: - QueryStatus

/// An enum representing the current status of a query.
///
/// You generally don't create instances of this enum directly, and instead you can access it via
/// ``QueryStateProtocol/status`` on your query's state.
public enum QueryStatus<Value: Sendable>: Sendable {
  /// The query has never been fetched.
  case idle

  /// The query is currently fetching data.
  case loading

  /// The query has completed with a result.
  case result(Result<Value, any Error>)
}

// MARK: - Case Checking

extension QueryStatus {
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
    case let .result(.success(value)): value
    default: nil
    }
  }

  /// The result error, if the status indicates that the query finished unsuccessfully.
  public var resultError: Error? {
    switch self {
    case let .result(.failure(error)): error
    default: nil
    }
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

extension QueryStatus {
  /// Maps the success value of this status if it indicates that the query finished successfully.
  ///
  /// If this status isn't successful, then it is returned instead.
  ///
  /// ```swift
  /// let status = QueryStatus<Int>.result(.success(10))
  /// let status2: QueryStatus<String> = status.mapSuccess { String($0) }
  /// ```
  ///
  /// - Parameter transform: A function to transform the value into a new value.
  /// - Returns: A status with the newly transformed value.
  public func mapSuccess<NewValue: Sendable, E: Error>(
    _ transform: (Value) throws(E) -> NewValue
  ) throws(E) -> QueryStatus<NewValue> {
    switch self {
    case let .result(.success(value)): try .result(.success(transform(value)))
    case let .result(.failure(error)): .result(.failure(error))
    case .idle: .idle
    case .loading: .loading
    }
  }

  /// Transforms this status into another ``QueryStatus`` based on the success value of this status
  /// if one is present.
  ///
  /// If this status isn't successful, then it is returned instead.
  ///
  /// ```swift
  /// let status = QueryStatus<Int>.result(.success(10))
  /// let status2: QueryStatus<String> = status.flatMapSuccess {
  ///   .result(.success(String($0)))
  /// }
  /// ```
  ///
  /// - Parameter transform: A function to transform the value into a new status.
  /// - Returns: The status returned from `transform`, or the current status if it isn't successful.
  public func flatMapSuccess<NewValue: Sendable, E: Error>(
    _ transform: (Value) throws(E) -> QueryStatus<NewValue>
  ) throws(E) -> QueryStatus<NewValue> {
    switch self {
    case let .result(.success(value)): try transform(value)
    case let .result(.failure(error)): .result(.failure(error))
    case .idle: .idle
    case .loading: .loading
    }
  }
}

// MARK: - QueryStateProtocol

extension QueryStateProtocol where StateValue == StatusValue {
  /// The current ``QueryStatus`` of this query.
  public var status: QueryStatus<StatusValue> {
    self.stateStatus
  }
}

extension QueryStateProtocol where StateValue == StatusValue? {
  /// The current ``QueryStatus`` of this query.
  public var status: QueryStatus<StatusValue> {
    self.stateStatus.flatMapSuccess { value in
      if let value {
        return .result(.success(value))
      } else {
        return .idle
      }
    }
  }
}

extension QueryStateProtocol {
  private var stateStatus: QueryStatus<StateValue> {
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
