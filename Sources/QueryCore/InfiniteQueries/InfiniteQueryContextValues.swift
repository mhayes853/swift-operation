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
    let pages = store.state.currentValue
    switch fetchType {
    case .allPages:
      self.request = InfiniteQueryPaging<PageID, PageValue>.Request.allPages
    case .nextPage:
      if let last = pages.last {
        self.request = InfiniteQueryPaging<PageID, PageValue>.Request.nextPageAfter(last)
      } else {
        self.request = InfiniteQueryPaging<PageID, PageValue>.Request.initialPage
      }
    case .previousPage:
      if let first = pages.first {
        self.request = InfiniteQueryPaging<PageID, PageValue>.Request.previousPageBefore(first)
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
    guard let request = self.request as? InfiniteQueryPaging<PageID, PageValue>.Request else {
      fatalError("TODO")
    }
    return request
  }

  func paging<Query: InfiniteQueryProtocol>(
    for query: Query
  ) -> InfiniteQueryPaging<Query.PageID, Query.PageValue> {
    guard let store = self.store as? InfiniteQueryStoreFor<Query> else {
      fatalError("TODO")
    }
    let pages = store.state.currentValue
    let latestPageId = pages.last?.id ?? query.initialPageId

    // NB: The state may have changed since we assigned the request type, so ensure that we're
    // using the most up-to-date pages from the store for the nextPageAfter and previousPageBefore
    // requests.
    let pagingRequest: InfiniteQueryPaging<Query.PageID, Query.PageValue>.Request =
      switch (self.request(Query.PageID.self, Query.PageValue.self), pages.last, pages.first) {
      case (.allPages, _, _): .allPages
      case let (.nextPageAfter, last?, _): .nextPageAfter(last)
      case let (.previousPageBefore, _, first?): .previousPageBefore(first)
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
