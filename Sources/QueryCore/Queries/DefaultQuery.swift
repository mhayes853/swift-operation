extension QueryProtocol {
  public func defaultValue(_ value: Self.Value) -> DefaultQuery<Self> {
    DefaultQuery(defaultValue: value, base: self)
  }
}

public struct DefaultQuery<Base: QueryProtocol>: QueryProtocol {
  public typealias StateValue = Base.Value

  let defaultValue: Base.Value
  let base: Base

  public var path: QueryPath {
    self.base.path
  }

  public func _setup(context: inout QueryContext) {
    self.base._setup(context: &context)
  }

  public func fetch(
    in context: QueryContext,
    currentValue: StateValue
  ) async throws -> Base.Value {
    try await self.base.fetch(
      in: context,
      currentValue: currentValue as! Base.StateValue  // TODO: - Report issue if cast fails?
    )
  }
}
