// MARK: - InfiniteQueryContextValues

struct PaginatedContextValues: Sendable {
  var fetchType: FetchType?
  var currentPagesTracker: PagesTracker?
  var requestSubscriptions = OperationSubscriptions<RequestSubscriber>()
}

// MARK: - RequestSubscriber

extension PaginatedContextValues {
  struct RequestSubscriber: Sendable {
    let onPageFetchingStarted: @Sendable (AnyHashableSendable, OperationContext) -> Void
    let onPageResultReceived:
      @Sendable (AnyHashableSendable, Result<any Sendable, any Error>, OperationContext) -> Void
    let onPageFetchingFinished: @Sendable (AnyHashableSendable, OperationContext) -> Void
  }

  func addRequestSubscriber<State: _PaginatedStateProtocol>(
    from handler: PaginatedEventHandler<State>,
    isTemporary: Bool
  ) -> OperationSubscription {
    let subscriber = RequestSubscriber(
      onPageFetchingStarted: { id, context in
        guard let id = id.base as? State.PageID else { return }
        handler.onPageFetchingStarted?(id, context)
      },
      onPageResultReceived: { id, result, context in
        guard let id = id.base as? State.PageID else { return }
        switch result {
        case .success(let page as Page<State.PageID, State.PageValue>):
          handler.onPageResultReceived?(id, .success(page), context)
        case .failure(let error):
          handler.onPageResultReceived?(id, .failure(error as! State.Failure), context)
        default: break
        }
      },
      onPageFetchingFinished: { id, context in
        guard let id = id.base as? State.PageID else { return }
        handler.onPageFetchingEnded?(id, context)
      }
    )
    return self.requestSubscriptions.add(handler: subscriber, isTemporary: isTemporary).subscription
  }
}

// MARK: - CurrentPageIdTracker

extension PaginatedContextValues {
  final class PagesTracker: Sendable {
    private let pages = RecursiveLock<(any Sendable)?>(nil)

    func pages<Query: PaginatedRequest>(
      for query: Query
    ) -> Pages<Query.PageID, Query.PageValue> {
      self.pages.withLock { $0 as? Pages<Query.PageID, Query.PageValue> } ?? []
    }

    func savePages(_ pages: any Sendable) {
      self.pages.withLock { $0 = pages }
    }
  }
}

// MARK: - FetchType

extension PaginatedContextValues {
  enum FetchType {
    case nextPage
    case previousPage
    case allPages
  }
}

// MARK: - OperationContext

extension OperationContext {
  func paging<Query: PaginatedRequest>(
    for query: Query
  ) -> Paging<Query.PageID, Query.PageValue> {
    guard let store = self.currentFetchingOperationStore?.base as? OperationStore<Query.State>
    else {
      return Paging(pageId: query.initialPageId, pages: [], request: .initialPage)
    }
    let state = store.state
    let pages = state.currentValue
    let request = state.request(in: self)
    let pageId =
      request == .initialPage ? query.initialPageId : pages.last?.id ?? query.initialPageId
    return Paging(pageId: pageId, pages: pages, request: request)
  }

  mutating func ensureInfiniteValues() -> PaginatedContextValues {
    if let infiniteValues {
      return infiniteValues
    }
    self.infiniteValues = PaginatedContextValues()
    return self.infiniteValues!
  }

  var infiniteValues: PaginatedContextValues? {
    get { self[InfiniteQueryContextValuesKey.self] }
    set { self[InfiniteQueryContextValuesKey.self] = newValue }
  }

  private enum InfiniteQueryContextValuesKey: Key {
    static var defaultValue: PaginatedContextValues? { nil }
  }
}
