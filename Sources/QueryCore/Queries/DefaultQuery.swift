import IdentifiedCollections

// MARK: - DefaultQuery

extension QueryProtocol {
  public func defaultValue(
    _ value: @autoclosure @escaping @Sendable () -> Value
  ) -> DefaultQuery<Self> {
    DefaultQuery(_defaultValue: value, query: self)
  }
}

public struct DefaultQuery<Query: QueryProtocol>: QueryProtocol {
  public typealias StateValue = Query.Value
  public typealias State = QueryState<StateValue, StateValue>

  let _defaultValue: @Sendable () -> Query.Value
  public let query: Query

  public var defaultValue: Query.Value {
    self._defaultValue()
  }

  public var path: QueryPath {
    self.query.path
  }

  public func _setup(context: inout QueryContext) {
    self.query._setup(context: &context)
  }

  public func fetch(in context: QueryContext) async throws -> Query.Value {
    try await self.query.fetch(in: context)
  }
}

// MARK: - DefaultInfiniteQuery

extension InfiniteQueryProtocol {
  public func defaultValue(
    _ value: @autoclosure @escaping @Sendable () -> StateValue
  ) -> DefaultInfiniteQuery<Self> {
    DefaultInfiniteQuery(_defaultValue: value, query: self)
  }
}

public struct DefaultInfiniteQuery<Query: InfiniteQueryProtocol>: QueryProtocol {
  public typealias StateValue = Query.StateValue

  let _defaultValue: @Sendable () -> Query.StateValue
  public let query: Query

  public var defaultValue: Query.StateValue {
    self._defaultValue()
  }

  public var path: QueryPath {
    self.query.path
  }

  public func _setup(context: inout QueryContext) {
    self.query._setup(context: &context)
  }

  public func fetch(in context: QueryContext) async throws -> Query.Value {
    try await self.query.fetch(in: context)
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
    in context: QueryContext
  ) async throws -> PageValue {
    try await self.query.fetchPage(using: paging, in: context)
  }
}
