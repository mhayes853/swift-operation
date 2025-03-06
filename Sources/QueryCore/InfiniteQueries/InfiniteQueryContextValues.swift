struct InfiniteQueryContextValues: Sendable {
  let fetchType: FetchType
  private let request: any Sendable
  private let store: any Sendable
}

extension InfiniteQueryContextValues {
  init<PageID: Hashable & Sendable, PageValue: Sendable>(
    fetchType: FetchType,
    store: InfiniteQueryStore<PageID, PageValue>
  ) {
    let state = store.state
    switch fetchType {
    case .allPages:
      self.request = InfiniteQueryPaging<PageID, PageValue>.Request.allPages
    case .nextPage:
      if let last = state.nextPageId {
        self.request = InfiniteQueryPaging<PageID, PageValue>.Request.nextPage(last)
      } else {
        self.request = InfiniteQueryPaging<PageID, PageValue>.Request.initialPage
      }
    case .previousPage:
      if let first = state.previousPageId {
        self.request = InfiniteQueryPaging<PageID, PageValue>.Request.previousPage(first)
      } else {
        self.request = InfiniteQueryPaging<PageID, PageValue>.Request.initialPage
      }
    }
    self.fetchType = fetchType
    self.store = store
  }
}

extension InfiniteQueryContextValues {
  enum FetchType {
    case nextPage
    case previousPage
    case allPages
  }
}

extension InfiniteQueryContextValues {
  func request<PageID: Hashable & Sendable, PageValue: Sendable>(
    _: PageID.Type,
    _: PageValue.Type
  ) -> InfiniteQueryPaging<PageID, PageValue>.Request {
    return self.request as! InfiniteQueryPaging<PageID, PageValue>.Request
  }

  func paging<Query: InfiniteQueryProtocol>(
    for query: Query
  ) -> InfiniteQueryPaging<Query.PageID, Query.PageValue> {
    let store = self.store as! InfiniteQueryStoreFor<Query>
    let state = store.state
    let pages = state.currentValue
    let latestPageId = pages.last?.id ?? query.initialPageId

    // NB: The state may have changed since we assigned the request type, so ensure that we're
    // using the most up-to-date pages from the store for the nextPageAfter and previousPageBefore
    // requests.
    let pagingRequest: InfiniteQueryPaging<Query.PageID, Query.PageValue>.Request =
      switch (
        self.request(Query.PageID.self, Query.PageValue.self), state.nextPageId,
        state.previousPageId
      ) {
      case (.allPages, _, _): .allPages
      case let (.nextPage, last?, _): .nextPage(last)
      case let (.previousPage, _, first?): .previousPage(first)
      default: .initialPage
      }
    return InfiniteQueryPaging(pageId: latestPageId, pages: pages, request: pagingRequest)
  }
}

extension QueryContext {
  var infiniteValues: InfiniteQueryContextValues? {
    get { self[InfiniteQueryContextValuesKey.self] }
    set { self[InfiniteQueryContextValuesKey.self] = newValue }
  }

  private enum InfiniteQueryContextValuesKey: Key {
    static var defaultValue: InfiniteQueryContextValues? { nil }
  }
}
