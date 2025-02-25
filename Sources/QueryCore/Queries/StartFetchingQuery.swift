public enum QueryStartFetchingCondition: Sendable {
  case subscribedTo
  case fetchManuallyCalled
}

extension QueryProtocol {
  public func startFetching(
    when condition: QueryStartFetchingCondition
  ) -> _StartFetchingQuery<Self> {
    _StartFetchingQuery(base: self, condition: condition)
  }
}

public struct _StartFetchingQuery<Base: QueryProtocol>: QueryProtocol {
  let base: Base
  let condition: QueryStartFetchingCondition

  public var path: QueryPath {
    self.base.path
  }

  public func fetch(in context: QueryContext) async throws -> Base.Value {
    try await self.base.fetch(in: context)
  }
}
