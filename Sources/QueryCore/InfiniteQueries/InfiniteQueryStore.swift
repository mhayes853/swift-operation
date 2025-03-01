import IdentifiedCollections

// MARK: - Type Aliases

public typealias InfiniteQueryStoreFor<
  Query: InfiniteQueryProtocol
> = InfiniteQueryStore<Query.PageID, Query.PageValue>

public typealias QueryStoreOfInfinitePages<PageID: Hashable & Sendable, PageValue: Sendable> =
  QueryStore<InfiniteQueryPages<PageID, PageValue>, InfiniteQueryPages<PageID, PageValue>>

// MARK: - InfiniteQueryStore

public final class InfiniteQueryStore<PageID: Hashable & Sendable, PageValue: Sendable>: Sendable {
  private let base: QueryStoreOfInfinitePages<PageID, PageValue>

  private init(base: QueryStoreOfInfinitePages<PageID, PageValue>) {
    self.base = base
  }
}

// MARK: - Store Initializers

extension InfiniteQueryStore {
  public convenience init?(store: QueryStoreOfInfinitePages<PageID, PageValue>) {
    nil
  }

  public convenience init?(casting store: AnyQueryStore) {
    nil
  }
}

// MARK: - Detached

extension InfiniteQueryStore {
  public static func detached<Query: InfiniteQueryProtocol>(
    query: Query,
    initialValue: Query.StateValue = [],
    initialContext: QueryContext = QueryContext()
  ) -> InfiniteQueryStoreFor<Query>
  where Query.Value == InfiniteQueryPagesFor<Query>, Query.StateValue == Query.Value {
    InfiniteQueryStoreFor<Query>(
      base: .detached(query: query, initialValue: initialValue, initialContext: initialContext)
    )
  }

  public static func detached<Query: InfiniteQueryProtocol>(
    query: DefaultQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> InfiniteQueryStoreFor<Query>
  where Query.Value == InfiniteQueryPagesFor<Query> {
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
  public var willFetchOnFirstSubscription: Bool {
    self.base.willFetchOnFirstSubscription
  }
}

// MARK: - State

extension InfiniteQueryStore {
  public var state: InfiniteQueryState<PageID, PageValue> {
    //InfiniteQueryState(base: self.base.state, currentPageId: fatalError())
    fatalError()
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
