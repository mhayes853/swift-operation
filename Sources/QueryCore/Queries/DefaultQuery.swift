extension QueryProtocol where Self.Value: Hashable {
  public func defaultValue(_ value: Self.Value) -> DefaultQuery<Self> {
    DefaultQuery(defaultValue: value, base: self)
  }
}

public struct DefaultQuery<Base: QueryProtocol>: QueryProtocol where Base.Value: Hashable {
  let defaultValue: Base.Value
  let base: Base

  public func fetch(in context: QueryContext) async throws -> Base.Value {
    try await self.base.fetch(in: context)
  }
}
