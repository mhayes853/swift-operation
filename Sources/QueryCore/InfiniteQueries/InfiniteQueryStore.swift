import Foundation
import IdentifiedCollections

// MARK: - Type Aliases

public typealias InfiniteQueryStoreFor<
  Query: InfiniteQueryProtocol
> = InfiniteQueryStore<Query.PageID, Query.PageValue>

// MARK: - InfiniteQueryStore

@dynamicMemberLookup
public final class InfiniteQueryStore<PageID: Hashable & Sendable, PageValue: Sendable>: Sendable {
  private let base: QueryStore<InfiniteQueryState<PageID, PageValue>>

  public init(store: QueryStore<InfiniteQueryState<PageID, PageValue>>) {
    self.base = store
  }
}

// MARK: - Store Initializers

extension InfiniteQueryStore {
  public convenience init?(casting store: OpaqueQueryStore) {
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
    initialValue: Query.State.StateValue = [],
    initialContext: QueryContext = QueryContext()
  ) -> InfiniteQueryStoreFor<Query> {
    InfiniteQueryStoreFor<Query>(
      store: .detached(
        query: query,
        initialState: InfiniteQueryState(
          initialValue: initialValue,
          initialPageId: query.initialPageId
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
    handler: InfiniteQueryEventHandler<PageID, PageValue> = InfiniteQueryEventHandler(),
    using context: QueryContext? = nil
  ) async throws -> InfiniteQueryPages<PageID, PageValue> {
    var context = context ?? self.context
    context.infiniteValues.fetchType = .allPages
    switch try await self.fetch(handler: handler, using: context).response {
    case let .allPages(pages):
      return pages
    default:
      return self.state.currentValue
    }
  }

  @discardableResult
  public func fetchNextPage(
    handler: InfiniteQueryEventHandler<PageID, PageValue> = InfiniteQueryEventHandler(),
    using context: QueryContext? = nil
  ) async throws -> InfiniteQueryPage<PageID, PageValue>? {
    guard self.hasNextPage else { return nil }
    var context = context ?? self.context
    context.infiniteValues.fetchType = .nextPage
    switch try await self.fetch(handler: handler, using: context).response {
    case let .nextPage(next):
      return next?.page
    case let .initialPage(page):
      return page
    default:
      return nil
    }
  }

  @discardableResult
  public func fetchPreviousPage(
    handler: InfiniteQueryEventHandler<PageID, PageValue> = InfiniteQueryEventHandler(),
    using context: QueryContext? = nil
  ) async throws -> InfiniteQueryPage<PageID, PageValue>? {
    guard self.hasPreviousPage else { return nil }
    var context = context ?? self.context
    context.infiniteValues.fetchType = .previousPage
    switch try await self.fetch(handler: handler, using: context).response {
    case let .previousPage(previous):
      return previous?.page
    case let .initialPage(page):
      return page
    default:
      return nil
    }
  }

  private func fetch(
    handler: InfiniteQueryEventHandler<PageID, PageValue>,
    using context: QueryContext
  ) async throws -> InfiniteQueryValue<PageID, PageValue> {
    let (subscription, _) = context.infiniteValues.subscriptions.add(
      handler: handler.erased(),
      isTemporary: true
    )
    defer { subscription.cancel() }
    return try await self.base.fetch(handler: self.queryStoreHandler(for: handler), using: context)
  }
}

// MARK: - Subscribe

extension InfiniteQueryStore {
  public func subscribe(
    with handler: InfiniteQueryEventHandler<PageID, PageValue>
  ) -> QuerySubscription {
    let (contextSubscription, _) = context.infiniteValues.subscriptions.add(
      handler: handler.erased()
    )
    let baseSubscription = self.base.subscribe(with: self.queryStoreHandler(for: handler))
    return QuerySubscription {
      baseSubscription.cancel()
      contextSubscription.cancel()
    }
  }
}

// MARK: - InfiniteQueryEventHandler

extension InfiniteQueryStore {
  private func queryStoreHandler(
    for handler: InfiniteQueryEventHandler<PageID, PageValue>
  ) -> QueryEventHandler<InfiniteQueryState<PageID, PageValue>.QueryValue> {
    QueryEventHandler(
      onFetchingStarted: { handler.onFetchingStarted?($0) },
      onFetchingEnded: { handler.onFetchingFinished?($0) },
      onResultReceived: {
        handler.onResultReceived?($0.map { [weak self] _ in self?.currentValue ?? [] }, $1)
      }
    )
  }
}
