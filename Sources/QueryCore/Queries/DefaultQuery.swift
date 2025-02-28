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

  public func fetch(in context: QueryContext) async throws -> Base.Value {
    try await self.base.fetch(in: context)
  }
}

extension DefaultQuery: InfiniteQueryProtocol where Base: InfiniteQueryProtocol {
  public typealias PageValue = Base.PageValue
  public typealias PageID = Base.PageID

  public var initialPageId: PageID {
    self.base.initialPageId
  }

  public func pageId(
    after page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>
  ) -> PageID? {
    self.base.pageId(after: page, using: paging)
  }

  public func pageId(
    before page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>
  ) -> PageID? {
    self.base.pageId(before: page, using: paging)
  }

  public func fetchPage(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) async throws -> PageValue {
    try await self.base.fetchPage(using: paging, in: context)
  }
}
