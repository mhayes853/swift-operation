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
  public typealias State = Query.State
  public typealias Value = Query.Value

  public let query: Query
  public let modifier: Modifier

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

extension ModifiedQuery: InfiniteQueryProtocol where Query: InfiniteQueryProtocol {
  public typealias PageValue = Query.PageValue
  public typealias PageID = Query.PageID

  public var initialPageId: PageID {
    self.query.initialPageId
  }

  public func pageId(
    after page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>
  ) -> PageID? {
    self.query.pageId(after: page, using: paging)
  }

  public func pageId(
    before page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>
  ) -> PageID? {
    self.query.pageId(before: page, using: paging)
  }

  public func fetchPage(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) async throws -> PageValue {
    try await self.query.fetchPage(using: paging, in: context)
  }
}

extension ModifiedQuery: MutationProtocol where Query: MutationProtocol {
  public func mutate(
    with arguments: Query.Arguments,
    in context: QueryContext
  ) async throws -> Value {
    try await self.query.mutate(with: arguments, in: context)
  }
}
