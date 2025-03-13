// MARK: - QueryCacheValue

public enum QueryCacheValue<Value: Sendable>: Sendable {
  case stale(Value)
  case fresh(Value)
}

// MARK: - Mapping

extension QueryCacheValue {
  public func map<T>(_ transform: (Value) -> T) -> QueryCacheValue<T> {
    switch self {
    case let .stale(value): .stale(transform(value))
    case let .fresh(value): .fresh(transform(value))
    }
  }

  public func flatMap<T>(_ transform: (Value) -> QueryCacheValue<T>) -> QueryCacheValue<T> {
    switch self {
    case let .stale(value): transform(value)
    case let .fresh(value): transform(value)
    }
  }
}

// MARK: - Base Conformances

extension QueryCacheValue: Hashable where Value: Hashable {}
extension QueryCacheValue: Equatable where Value: Equatable {}
