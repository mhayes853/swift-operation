// MARK: - InfiniteQueryContextValues

struct InfiniteQueryContextValues: Sendable {
  let fetchType: FetchType
}

// MARK: - FetchType

extension InfiniteQueryContextValues {
  enum FetchType {
    case nextPage
    case previousPage
    case allPages
  }
}

// MARK: - QueryContext

extension QueryContext {
  func paging<Query: InfiniteQueryProtocol>(
    for query: Query
  ) -> InfiniteQueryPaging<Query.PageID, Query.PageValue> {
    guard let state = self.queryStateLoader?.state(as: Query.State.self) else {
      return InfiniteQueryPaging(pageId: query.initialPageId, pages: [], request: .initialPage)
    }
    let pages = state.currentValue
    let latestPageId = pages.last?.id ?? query.initialPageId
    return InfiniteQueryPaging(
      pageId: latestPageId,
      pages: pages,
      request: state.request(in: self)
    )
  }

  var infiniteValues: InfiniteQueryContextValues? {
    get { self[InfiniteQueryContextValuesKey.self] }
    set { self[InfiniteQueryContextValuesKey.self] = newValue }
  }

  private enum InfiniteQueryContextValuesKey: Key {
    static var defaultValue: InfiniteQueryContextValues? { nil }
  }
}
