// MARK: - QueryModifier

public protocol QueryModifier<Query>: Sendable {
  associatedtype Query: QueryRequest

  func setup(context: inout QueryContext, using query: Query)

  func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value
}

extension QueryModifier {
  public func setup(context: inout QueryContext, using query: Query) {
    query.setup(context: &context)
  }
}

// MARK: - ModifiedQuery

extension QueryRequest {
  public func modifier<Modifier: QueryModifier>(
    _ modifier: Modifier
  ) -> ModifiedQuery<Self, Modifier> {
    ModifiedQuery(query: self, modifier: modifier)
  }
}

public struct ModifiedQuery<Query: QueryRequest, Modifier: QueryModifier>: QueryRequest
where Modifier.Query == Query {
  public typealias State = Query.State
  public typealias Value = Query.Value

  public let query: Query
  public let modifier: Modifier

  public var path: QueryPath {
    self.query.path
  }

  public func setup(context: inout QueryContext) {
    self.modifier.setup(context: &context, using: query)
  }

  public func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await self.modifier.fetch(in: context, using: query, with: continuation)
  }
}
