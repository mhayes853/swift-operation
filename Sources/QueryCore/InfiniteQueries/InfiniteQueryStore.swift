import ConcurrencyExtras
import IdentifiedCollections

// MARK: - Type Aliases

public typealias InfiniteQueryStoreFor<
  Query: InfiniteQueryProtocol
> = InfiniteQueryStore<Query.PageID, Query.PageValue>

public typealias InfiniteQueryStore<PageID: Hashable & Sendable, PageValue: Sendable> =
  QueryStore<InfiniteQueryState<PageID, PageValue>>

// MARK: - Store Initializers

extension InfiniteQueryStore {
  //public convenience init?(store: QueryStoreOfInfinitePages<State.PageID, State.PageValue>) {
  //  guard store.query() is any InfiniteQueryProtocol else { return nil }
  //  self.init(base: store)
  //}
}

// MARK: - Detached

extension InfiniteQueryStore {
  //public static func detached<Query: InfiniteQueryProtocol>(
  //  query: Query,
  //  initialValue: Query.StateValue = [],
  //  initialContext: QueryContext = QueryContext()
  //) -> InfiniteQueryStoreFor<Query>
  //where
  //  Query.Value == InfiniteQueryPagesFor<Query>, Query.StateValue == Query.Value,
  //  Query.State == InfiniteQueryState<Query.PageID, Query.PageValue>
  //{
  //  InfiniteQueryLocal.$currentPageId.withValue(AnyHashableSendable(query.initialPageId)) {
  //    InfiniteQueryStoreFor<Query>(
  //      base: .detached(
  //        query: query,
  //        initialValue: initialValue,
  //        initialContext: initialContext
  //      )
  //    )
  //  }
  //}

  //public static func detached<Query: InfiniteQueryProtocol>(
  //  query: DefaultQuery<Query>,
  //  initialContext: QueryContext = QueryContext()
  //) -> InfiniteQueryStoreFor<Query>
  //where
  //  Query.Value == InfiniteQueryPagesFor<DefaultQuery<Query>>, Query.StateValue == Query.Value,
  //  Query.State == InfiniteQueryState<Query.PageID, Query.PageValue>
  //{
  //  .detached(query: query, initialValue: query.defaultValue, initialContext: initialContext)
  //}
}

// MARK: - Fetch

extension InfiniteQueryStore where State: _InfiniteQueryStateProtocol {
  @discardableResult
  public func fetchAllPages(
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPages<State.PageID, State.PageValue> {
    []
  }

  @discardableResult
  public func fetchNextPage(
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    nil
  }

  @discardableResult
  public func fetchPreviousPage(
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    nil
  }
}

// MARK: - Subscribe

extension InfiniteQueryStore where State: _InfiniteQueryStateProtocol {
  public func subscribe(
    with handler: InfiniteQueryEventHandler<State.PageID, State.PageValue>
  ) -> QuerySubscription {
    QuerySubscription {}
  }
}
