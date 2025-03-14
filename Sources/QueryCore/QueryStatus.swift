import IdentifiedCollections

// MARK: - QueryStatus

public enum QueryStatus<Value: Sendable>: Sendable {
  case idle
  case loading
  case result(Result<Value, any Error>)
}

// MARK: - Case Checking

extension QueryStatus {
  public var isIdle: Bool {
    switch self {
    case .idle: true
    default: false
    }
  }

  public var isLoading: Bool {
    switch self {
    case .loading: true
    default: false
    }
  }

  public var resultValue: Value? {
    switch self {
    case let .result(.success(value)): value
    default: nil
    }
  }

  public var resultError: Error? {
    switch self {
    case let .result(.failure(error)): error
    default: nil
    }
  }

  public var isSuccessful: Bool {
    self.resultValue != nil
  }

  public var isFailure: Bool {
    self.resultError != nil
  }

  public var isCancelled: Bool {
    self.resultError is CancellationError
  }
}

// MARK: - Mapping

extension QueryStatus {
  public func mapSuccess<NewValue: Sendable>(
    _ transform: (Value) -> NewValue
  ) -> QueryStatus<NewValue> {
    switch self {
    case let .result(.success(value)): .result(.success(transform(value)))
    case let .result(.failure(error)): .result(.failure(error))
    case .idle: .idle
    case .loading: .loading
    }
  }

  public func flatMapSuccess<NewValue: Sendable>(
    _ transform: (Value) -> QueryStatus<NewValue>
  ) -> QueryStatus<NewValue> {
    switch self {
    case let .result(.success(value)): transform(value)
    case let .result(.failure(error)): .result(.failure(error))
    case .idle: .idle
    case .loading: .loading
    }
  }
}

// MARK: - QueryStateProtocol

extension QueryStateProtocol where StateValue == StatusValue {
  public var status: QueryStatus<StatusValue> {
    self.stateStatus
  }
}

extension QueryStateProtocol where StateValue == StatusValue? {
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
