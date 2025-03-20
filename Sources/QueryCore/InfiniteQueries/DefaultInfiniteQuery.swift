import IdentifiedCollections

extension InfiniteQueryProtocol {
  public func defaultValue(
    _ value: @autoclosure @escaping @Sendable () -> State.StateValue
  ) -> DefaultInfiniteQuery<Self> {
    DefaultInfiniteQuery(_defaultValue: value, query: self)
  }
}

public struct DefaultInfiniteQuery<Query: InfiniteQueryProtocol>: QueryProtocol {
  let _defaultValue: @Sendable () -> Query.State.StateValue
  public let query: Query

  public var defaultValue: Query.State.StateValue {
    self._defaultValue()
  }

  public var path: QueryPath {
    self.query.path
  }

  public func setup(context: inout QueryContext) {
    self.query.setup(context: &context)
  }

  public func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await self.query.fetch(in: context, with: continuation)
  }
}

extension DefaultInfiniteQuery: InfiniteQueryProtocol {
  public typealias PageValue = Query.PageValue
  public typealias PageID = Query.PageID
  public typealias State = Query.State

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
    in context: QueryContext,
    with continuation: QueryContinuation<PageValue>
  ) async throws -> PageValue {
    try await self.query.fetchPage(using: paging, in: context, with: continuation)
  }
}
