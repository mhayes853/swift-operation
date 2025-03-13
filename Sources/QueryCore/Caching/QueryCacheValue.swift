public enum QueryCacheValue<Value: Sendable>: Sendable {
  case stale(Value)
  case fresh(Value)
}

extension QueryCacheValue: Hashable where Value: Hashable {}
extension QueryCacheValue: Equatable where Value: Equatable {}
