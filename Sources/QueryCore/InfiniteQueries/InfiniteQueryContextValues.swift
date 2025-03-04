struct InfiniteQueryContextValues: Sendable {
  var fetchType = FetchType.allPages
  var currentPages: (any Sendable)?
}

extension InfiniteQueryContextValues {
  enum FetchType {
    case nextPage
    case previousPage
    case currentPage
    case allPages
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
    let currentPageId = pages.last?.id ?? query.initialPageId
    return InfiniteQueryPaging(
      pageId: currentPageId,
      pages: pages,
      request: self.request(Query.self, currentPageId: currentPageId, pages: pages)
    )
  }

  private func request<Query: InfiniteQueryProtocol>(
    _: Query.Type,
    currentPageId: Query.PageID,
    pages: InfiniteQueryPages<Query.PageID, Query.PageValue>
  ) -> InfiniteQueryPaging<Query.PageID, Query.PageValue>.Request {
    switch self.fetchType {
    case .allPages:
      return .allPages
    case .currentPage:
      return .currentPage(currentPageId)
    case .nextPage:
      if let last = pages.last {
        return .nextPageAfter(last)
      } else {
        return .currentPage(currentPageId)
      }
    case .previousPage:
      if let first = pages.first {
        return .previousPageBefore(first)
      } else {
        return .currentPage(currentPageId)
      }
    }
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
