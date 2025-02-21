extension QueryProtocol {
  public func defaultValue(_ value: Self.Value) -> DefaultQuery<Self> {
    DefaultQuery(defaultValue: value, base: self)
  }
}

public struct DefaultQuery<Base: QueryProtocol>: QueryProtocol {
  let defaultValue: Base.Value
  let base: Base

  public var id: Base.ID {
    self.base.id
  }

  public func fetch(in context: QueryContext) async throws -> Base.Value {
    try await self.base.fetch(in: context)
  }
}
