struct InfiniteQueryContextValues: Sendable {
  var fetchType = FetchType.allPages
  var currentPages: (any Sendable)?
}

extension InfiniteQueryContextValues {
  enum FetchType {
    case nextPage
    case currentPage
    case allPages
    case previousPage
  }
}

extension InfiniteQueryContextValues {
  func paging<Query: InfiniteQueryProtocol>(
    for query: Query
  ) -> InfiniteQueryPaging<Query.PageID, Query.PageValue> {
    guard let pages = currentPages as? InfiniteQueryPages<Query.PageID, Query.PageValue>
    else {
      fatalError("TODO")
    }
    return InfiniteQueryPaging(currentPageId: pages.last?.id ?? query.initialPageId, pages: pages)
  }
}

extension QueryContext {
  var infiniteValues: InfiniteQueryContextValues {
    get { self[InfiniteQueryContextValuesKey.self] }
    set { self[InfiniteQueryContextValuesKey.self] = newValue }
  }

  private enum InfiniteQueryContextValuesKey: Key {
    static var defaultValue: InfiniteQueryContextValues {
      InfiniteQueryContextValues()
    }
  }
}
