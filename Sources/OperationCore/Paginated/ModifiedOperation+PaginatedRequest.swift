extension ModifiedOperation: PaginatedRequest where Operation: PaginatedRequest {
  public typealias PageValue = Operation.PageValue
  public typealias PageID = Operation.PageID
  public typealias PageFailure = Operation.PageFailure

  public var initialPageId: PageID {
    self.operation.initialPageId
  }

  public func pageId(
    after page: Page<PageID, PageValue>,
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext
  ) -> PageID? {
    self.operation.pageId(after: page, using: paging, in: context)
  }

  public func pageId(
    before page: Page<PageID, PageValue>,
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext
  ) -> PageID? {
    self.operation.pageId(before: page, using: paging, in: context)
  }

  public func fetchPage(
    isolation: isolated (any Actor)?,
    using paging: Paging<PageID, PageValue>,
    in context: OperationContext,
    with continuation: OperationContinuation<PageValue, PageFailure>
  ) async throws(PageFailure) -> PageValue {
    try await self.operation.fetchPage(
      isolation: isolation,
      using: paging,
      in: context,
      with: continuation
    )
  }
}
