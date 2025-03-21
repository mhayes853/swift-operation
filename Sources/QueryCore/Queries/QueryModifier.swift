// MARK: - QueryModifier

public protocol QueryModifier<Query>: Sendable {
  associatedtype Query: QueryProtocol

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

extension ModifiedQuery: InfiniteQueryProtocol where Query: InfiniteQueryProtocol {
  public typealias PageValue = Query.PageValue
  public typealias PageID = Query.PageID

  public var initialPageId: PageID {
    self.query.initialPageId
  }

  public func pageId(
    after page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) -> PageID? {
    self.query.pageId(after: page, using: paging, in: context)
  }

  public func pageId(
    before page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) -> PageID? {
    self.query.pageId(before: page, using: paging, in: context)
  }

  public func fetchPage(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext,
    with continuation: QueryContinuation<PageValue>
  ) async throws -> PageValue {
    try await self.query.fetchPage(using: paging, in: context, with: continuation)
  }
}

extension ModifiedQuery: MutationProtocol where Query: MutationProtocol {
  public func mutate(
    with arguments: Query.Arguments,
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value {
    try await self.query.mutate(with: arguments, in: context, with: continuation)
  }
}
