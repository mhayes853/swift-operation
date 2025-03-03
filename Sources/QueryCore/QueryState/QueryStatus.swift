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

extension QueryStateProtocol {
  public var status: QueryStatus<QueryValue> {
    if self.isLoading {
      return .loading
    } else if self.valueUpdateCount == 0 && self.errorUpdateCount == 0 {
      return .idle
    } else if let currentValue = self.currentValue as? QueryValue, self.hasMostRecentValueUpdate {
      return .result(.success(currentValue))
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
