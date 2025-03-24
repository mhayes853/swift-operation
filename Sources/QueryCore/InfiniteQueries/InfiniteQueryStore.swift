import Foundation
import IdentifiedCollections

// MARK: - Type Aliases

public typealias InfiniteQueryStoreFor<
  Query: InfiniteQueryRequest
> = InfiniteQueryStore<Query.PageID, Query.PageValue>

// MARK: - InfiniteQueryStore

@dynamicMemberLookup
public final class InfiniteQueryStore<PageID: Hashable & Sendable, PageValue: Sendable>: Sendable {
  public let base: QueryStore<InfiniteQueryState<PageID, PageValue>>

  public init(store: QueryStore<InfiniteQueryState<PageID, PageValue>>) {
    self.base = store
  }
}

// MARK: - Detached

extension InfiniteQueryStore {
  public static func detached<Query: InfiniteQueryRequest<PageID, PageValue>>(
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

  public static func detached<Query: InfiniteQueryRequest<PageID, PageValue>>(
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

// MARK: - Current Value

extension InfiniteQueryStore {
  public var currentValue: InfiniteQueryPages<PageID, PageValue> {
    get { self.base.currentValue }
    set { self.base.currentValue = newValue }
  }
}

// MARK: - Reset

extension InfiniteQueryStore {
  public func reset(using context: QueryContext? = nil) {
    self.base.reset(using: context)
  }
}

// MARK: - Fetch All Pages

extension InfiniteQueryStore {
  @discardableResult
  public func fetchAllPages(
    using configuration: QueryTaskConfiguration? = nil,
    handler: InfiniteQueryEventHandler<PageID, PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPages<PageID, PageValue> {
    let value = try await self.fetch(
      using: self.fetchAllPagesTaskConfiguration(using: configuration),
      handler: handler
    )
    return self.allPages(from: value)
  }

  public func fetchAllPagesTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPages<PageID, PageValue>> {
    self.base.fetchTask(using: self.fetchAllPagesTaskConfiguration(using: configuration))
      .map(self.allPages(from:))
  }

  private func allPages(
    from value: InfiniteQueryValue<PageID, PageValue>
  ) -> InfiniteQueryPages<PageID, PageValue> {
    switch value.response {
    case let .allPages(pages): pages
    default: self.state.currentValue
    }
  }

  private func fetchAllPagesTaskConfiguration(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTaskConfiguration {
    var configuration = configuration ?? QueryTaskConfiguration(context: self.context)
    configuration.context.infiniteValues.fetchType = .allPages
    configuration.name = self.fetchAllPagesTaskName
    return configuration
  }

  private var fetchAllPagesTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Fetch All Pages Task"
  }
}

// MARK: - Fetch Next Page

extension InfiniteQueryStore {
  @discardableResult
  public func fetchNextPage(
    using configuration: QueryTaskConfiguration? = nil,
    handler: InfiniteQueryEventHandler<PageID, PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<PageID, PageValue>? {
    guard self.hasNextPage else { return nil }
    let value = try await self.fetch(
      using: self.fetchNextPageTaskConfiguration(using: configuration),
      handler: handler
    )
    return self.nextPage(from: value)
  }

  public func fetchNextPageTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPage<PageID, PageValue>?> {
    guard self.hasNextPage else {
      return QueryTask(
        configuration: self.fetchNextPageTaskConfiguration(using: configuration)
      ) { _ in nil }
    }
    return self.base.fetchTask(using: self.fetchNextPageTaskConfiguration(using: configuration))
      .map(self.nextPage(from:))
  }

  private func nextPage(
    from value: InfiniteQueryValue<PageID, PageValue>
  ) -> InfiniteQueryPage<PageID, PageValue>? {
    switch value.response {
    case let .nextPage(next): next?.page
    case let .initialPage(page): page
    default: nil
    }
  }

  private func fetchNextPageTaskConfiguration(
    using configuration: QueryTaskConfiguration?
  ) -> QueryTaskConfiguration {
    var configuration = configuration ?? QueryTaskConfiguration(context: self.context)
    configuration.context.infiniteValues.fetchType = .nextPage
    configuration.name = configuration.name ?? self.fetchNextPageTaskName
    return configuration
  }

  private var fetchNextPageTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Fetch Next Page Task"
  }
}

// MARK: - Fetch Previous Page

extension InfiniteQueryStore {
  @discardableResult
  public func fetchPreviousPage(
    using configuration: QueryTaskConfiguration? = nil,
    handler: InfiniteQueryEventHandler<PageID, PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<PageID, PageValue>? {
    guard self.hasPreviousPage else { return nil }
    let value = try await self.fetch(
      using: self.fetchPreviousPageTaskConfiguration(using: configuration),
      handler: handler
    )
    return self.previousPage(from: value)
  }

  public func fetchPreviousPageTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPage<PageID, PageValue>?> {
    guard self.hasPreviousPage else {
      return QueryTask(
        configuration: self.fetchPreviousPageTaskConfiguration(using: configuration)
      ) { _ in nil }
    }
    return self.base.fetchTask(using: self.fetchPreviousPageTaskConfiguration(using: configuration))
      .map(self.previousPage(from:))
  }

  private func previousPage(
    from value: InfiniteQueryValue<PageID, PageValue>
  ) -> InfiniteQueryPage<PageID, PageValue>? {
    switch value.response {
    case let .previousPage(previous): previous?.page
    case let .initialPage(page): page
    default: nil
    }
  }

  private func fetchPreviousPageTaskConfiguration(
    using configuration: QueryTaskConfiguration?
  ) -> QueryTaskConfiguration {
    var configuration = configuration ?? QueryTaskConfiguration(context: self.context)
    configuration.context.infiniteValues.fetchType = .previousPage
    configuration.name = configuration.name ?? self.fetchPreviousPageTaskName
    return configuration
  }

  private var fetchPreviousPageTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Fetch Previous Page Task"
  }
}

// MARK: - Fetch

extension InfiniteQueryStore {
  private func fetch(
    using configuration: QueryTaskConfiguration,
    handler: InfiniteQueryEventHandler<PageID, PageValue>
  ) async throws -> InfiniteQueryValue<PageID, PageValue> {
    let (subscription, _) = context.infiniteValues.subscriptions.add(
      handler: handler.erased(),
      isTemporary: true
    )
    defer { subscription.cancel() }
    return try await self.base.fetch(
      using: configuration,
      handler: self.queryStoreHandler(for: handler)
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
  ) -> QueryEventHandler<InfiniteQueryState<PageID, PageValue>> {
    QueryEventHandler(
      onFetchingStarted: handler.onFetchingStarted,
      onFetchingEnded: handler.onFetchingFinished,
      onResultReceived: { result, context in
        guard context.queryResultUpdateReason == .returnedFinalResult else { return }
        handler.onResultReceived?(result.map { [weak self] _ in self?.currentValue ?? [] }, context)
      },
      onStateChanged: handler.onStateChanged
    )
  }
}
