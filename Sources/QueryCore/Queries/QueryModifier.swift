// MARK: - QueryModifier

public protocol QueryModifier<Query>: Sendable {
  associatedtype Query: QueryProtocol

  func _setup(context: inout QueryContext, using query: Query)

  func fetch(in context: QueryContext, using query: Query) async throws -> Query.Value
}

extension QueryModifier {
  public func _setup(context: inout QueryContext, using query: Query) {
    query._setup(context: &context)
  }
}

// MARK: - ModifiedQuery

extension QueryProtocol {
  public func modifier<Modifier: QueryModifier>(
    _ modifier: Modifier
  ) -> ModifiedQuery<Self, Modifier> {
    ModifiedQuery(query: self, modifier: modifier)
  }
}

public struct ModifiedQuery<Query: QueryProtocol, Modifier: QueryModifier>: QueryProtocol
where Modifier.Query == Query {
  let query: Query
  let modifier: Modifier

  public var path: QueryPath {
    self.query.path
  }

  public func _setup(context: inout QueryContext) {
    self.modifier._setup(context: &context, using: query)
  }

  public func fetch(in context: QueryContext) async throws -> Query.Value {
    try await self.modifier.fetch(in: context, using: query)
  }
}
