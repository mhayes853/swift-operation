import ConcurrencyExtras

// MARK: - InfiniteQueryContextValues

struct InfiniteQueryContextValues: Sendable {
  var fetchType: FetchType?
  var currentPagesTracker: PagesTracker?
  let subscriptions = QuerySubscriptions<
    InfiniteQueryEventHandler<AnyHashableSendable, any Sendable>
  >()
}

// MARK: - CurrentPageIdTracker

extension InfiniteQueryContextValues {
  final class PagesTracker: Sendable {
    private let pages = Lock<(any Sendable)?>(nil)

    func pages<Query: InfiniteQueryRequest>(
      for query: Query
    ) -> InfiniteQueryPages<Query.PageID, Query.PageValue> {
      self.pages.withLock { $0 as? InfiniteQueryPages<Query.PageID, Query.PageValue> } ?? []
    }

    func savePages(_ pages: any Sendable) {
      self.pages.withLock { $0 = pages }
    }
  }
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
  func paging<Query: InfiniteQueryRequest>(
    for query: Query
  ) -> InfiniteQueryPaging<Query.PageID, Query.PageValue> {
    guard let store = self.currentQueryStore?.base as? QueryStore<Query.State> else {
      return InfiniteQueryPaging(pageId: query.initialPageId, pages: [], request: .initialPage)
    }
    let state = store.state
    let pages = state.currentValue
    let latestPageId = pages.last?.id ?? query.initialPageId
    return InfiniteQueryPaging(
      pageId: latestPageId,
      pages: pages,
      request: state.request(in: self)
    )
  }

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
