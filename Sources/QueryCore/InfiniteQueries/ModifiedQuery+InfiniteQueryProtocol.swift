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
