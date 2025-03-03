import IdentifiedCollections

// MARK: - Type Aliases

public typealias InfiniteQueryStoreFor<
  Query: InfiniteQueryProtocol
> = InfiniteQueryStore<Query.PageID, Query.PageValue>

// MARK: - InfiniteQueryStore

public final class InfiniteQueryStore<PageID: Hashable & Sendable, PageValue: Sendable>: Sendable {
  private let base: QueryStore<InfiniteQueryState<PageID, PageValue>>

  public init(store: QueryStore<InfiniteQueryState<PageID, PageValue>>) {
    self.base = store
  }
}

// MARK: - Store Initializers

extension InfiniteQueryStore {
  public convenience init?(casting store: AnyQueryStore) {
    guard let store = QueryStore<InfiniteQueryState<PageID, PageValue>>(casting: store) else {
      return nil
    }
    self.init(store: store)
  }
}

// MARK: - Detached

extension InfiniteQueryStore {
  public static func detached<Query: InfiniteQueryProtocol<PageID, PageValue>>(
    query: Query,
    initialValue: Query.StateValue = [],
    initialContext: QueryContext = QueryContext()
  ) -> InfiniteQueryStoreFor<Query> {
    InfiniteQueryStoreFor<Query>(
      store: .detached(
        query: query,
        initialState: InfiniteQueryState(
          initialValue: initialValue,
          currentPageId: query.initialPageId
        ),
        initialContext: initialContext
      )
    )
  }

  public static func detached<Query: InfiniteQueryProtocol<PageID, PageValue>>(
    query: DefaultInfiniteQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> InfiniteQueryStoreFor<Query> {
    .detached(query: query, initialValue: query.defaultValue, initialContext: initialContext)
  }
}

// MARK: - Path

extension InfiniteQueryStore {
  public var path: QueryPath {
    self.base.path
  }
}

// MARK: - Context

extension InfiniteQueryStore {
  public var context: QueryContext {
    get { self.base.context }
    set { self.base.context = newValue }
  }
}

// MARK: - Automatic Fetching

extension InfiniteQueryStore {
  public var isAutomaticFetchingEnabled: Bool {
    self.base.isAutomaticFetchingEnabled
  }
}

// MARK: - State

extension InfiniteQueryStore {
  public var state: InfiniteQueryState<PageID, PageValue> {
    self.base.state
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<InfiniteQueryState<PageID, PageValue>, NewValue>
  ) -> NewValue {
    self.state[keyPath: keyPath]
  }
}

// MARK: - Fetch

extension InfiniteQueryStore {
  @discardableResult
  public func fetchAllPages(
    handler: InfiniteQueryEventHandler<PageID, PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPages<PageID, PageValue> {
    []
  }

  @discardableResult
  public func fetchNextPage(
    handler: InfiniteQueryEventHandler<PageID, PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<PageID, PageValue>? {
    nil
  }

  @discardableResult
  public func fetchPreviousPage(
    handler: InfiniteQueryEventHandler<PageID, PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<PageID, PageValue>? {
    nil
  }
}

// MARK: - Subscribe

extension InfiniteQueryStore {
  public var subscriberCount: Int {
    self.base.subscriberCount
  }

  public func subscribe(
    with handler: InfiniteQueryEventHandler<PageID, PageValue>
  ) -> QuerySubscription {
    QuerySubscription {}
  }
}
