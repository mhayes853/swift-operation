import Foundation
import IdentifiedCollections

// MARK: - Type Aliases

public typealias InfiniteQueryStoreFor<
  Query: InfiniteQueryProtocol
> = InfiniteQueryStore<Query.PageID, Query.PageValue>

// MARK: - InfiniteQueryStore

@dynamicMemberLookup
public final class InfiniteQueryStore<PageID: Hashable & Sendable, PageValue: Sendable>: Sendable {
  public let base: QueryStore<InfiniteQueryState<PageID, PageValue>>

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

// MARK: - Fetch All Pages

extension InfiniteQueryStore {
  @discardableResult
  public func fetchAllPages(
    taskName: String? = nil,
    handler: InfiniteQueryEventHandler<PageID, PageValue> = InfiniteQueryEventHandler(),
    using context: QueryContext? = nil
  ) async throws -> InfiniteQueryPages<PageID, PageValue> {
    var context = context ?? self.context
    context.infiniteValues.fetchType = .allPages
    let value = try await self.fetch(
      taskName: taskName ?? self.fetchAllPagesTaskName,
      handler: handler,
      using: context
    )
    return self.allPages(from: value)
  }

  public func fetchAllPagesTask(
    name: String? = nil,
    using context: QueryContext? = nil
  ) -> QueryTask<InfiniteQueryPages<PageID, PageValue>> {
    var context = context ?? self.context
    context.infiniteValues.fetchType = .allPages
    return self.base.fetchTask(name: name ?? self.fetchAllPagesTaskName, using: context)
      .map(self.allPages(from:))
  }

  private func allPages(
    from value: InfiniteQueryValue<PageID, PageValue>
  ) -> InfiniteQueryPages<PageID, PageValue> {
    switch value.response {
    case let .allPages(pages):
      return pages
    default:
      return self.state.currentValue
    }
  }

  private var fetchAllPagesTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Fetch All Pages Task"
  }
}

// MARK: - Fetch Next Page

extension InfiniteQueryStore {

  @discardableResult
  public func fetchNextPage(
    taskName: String? = nil,
    handler: InfiniteQueryEventHandler<PageID, PageValue> = InfiniteQueryEventHandler(),
    using context: QueryContext? = nil
  ) async throws -> InfiniteQueryPage<PageID, PageValue>? {
    guard self.hasNextPage else { return nil }
    var context = context ?? self.context
    context.infiniteValues.fetchType = .nextPage
    let value = try await self.fetch(
      taskName: taskName ?? self.fetchNextPageTaskName,
      handler: handler,
      using: context
    )
    return self.nextPage(from: value)
  }

  public func fetchNextPageTask(
    name: String? = nil,
    using context: QueryContext? = nil
  ) -> QueryTask<InfiniteQueryPage<PageID, PageValue>?> {
    guard self.hasNextPage else {
      return QueryTask(name: name ?? self.fetchNextPageTaskName, context: QueryContext()) { _ in
        nil
      }
    }
    var context = context ?? self.context
    context.infiniteValues.fetchType = .nextPage
    return self.base.fetchTask(name: name ?? self.fetchNextPageTaskName, using: context)
      .map(self.nextPage(from:))
  }

  private func nextPage(
    from value: InfiniteQueryValue<PageID, PageValue>
  ) -> InfiniteQueryPage<PageID, PageValue>? {
    switch value.response {
    case let .nextPage(next):
      return next?.page
    case let .initialPage(page):
      return page
    default:
      return nil
    }
  }

  private var fetchNextPageTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Fetch Next Page Task"
  }
}

// MARK: - Fetch Previous Page

extension InfiniteQueryStore {
  @discardableResult
  public func fetchPreviousPage(
    taskName: String? = nil,
    handler: InfiniteQueryEventHandler<PageID, PageValue> = InfiniteQueryEventHandler(),
    using context: QueryContext? = nil
  ) async throws -> InfiniteQueryPage<PageID, PageValue>? {
    guard self.hasPreviousPage else { return nil }
    var context = context ?? self.context
    context.infiniteValues.fetchType = .previousPage
    let value = try await self.fetch(
      taskName: taskName ?? fetchPreviousPageTaskName,
      handler: handler,
      using: context
    )
    return self.previousPage(from: value)
  }

  public func fetchPreviousPageTask(
    name: String? = nil,
    using context: QueryContext? = nil
  ) -> QueryTask<InfiniteQueryPage<PageID, PageValue>?> {
    guard self.hasPreviousPage else {
      return QueryTask(name: name ?? self.fetchPreviousPageTaskName, context: QueryContext()) { _ in
        nil
      }
    }
    var context = context ?? self.context
    context.infiniteValues.fetchType = .previousPage
    return self.base.fetchTask(name: name ?? self.fetchPreviousPageTaskName, using: context)
      .map(self.previousPage(from:))
  }

  private func previousPage(
    from value: InfiniteQueryValue<PageID, PageValue>
  ) -> InfiniteQueryPage<PageID, PageValue>? {
    switch value.response {
    case let .previousPage(previous):
      return previous?.page
    case let .initialPage(page):
      return page
    default:
      return nil
    }
  }

  private var fetchPreviousPageTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Fetch Previous Page Task"
  }
}

// MARK: - Fetch

extension InfiniteQueryStore {
  private func fetch(
    taskName: String,
    handler: InfiniteQueryEventHandler<PageID, PageValue>,
    using context: QueryContext
  ) async throws -> InfiniteQueryValue<PageID, PageValue> {
    let (subscription, _) = context.infiniteValues.subscriptions.add(
      handler: handler.erased(),
      isTemporary: true
    )
    defer { subscription.cancel() }
    return try await self.base.fetch(
      taskName: taskName,
      handler: self.queryStoreHandler(for: handler),
      using: context
    )
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
      onFetchingStarted: handler.onFetchingStarted,
      onFetchingEnded: handler.onFetchingFinished,
      onResultReceived: {
        handler.onResultReceived?($0.map { [weak self] _ in self?.currentValue ?? [] }, $1)
      }
    )
  }
}
