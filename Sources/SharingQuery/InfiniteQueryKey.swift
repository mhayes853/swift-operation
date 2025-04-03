import IdentifiedCollections
import Query
import Sharing

// MARK: - InfiniteQueryKey

extension SharedKey {
  public static func infiniteQuery<Query: InfiniteQueryRequest>(
    _ query: Query,
    initialValue: Query.State.StateValue = [],
    client: QueryClient? = nil
  ) -> Self where Self == InfiniteQueryKey<Query.PageID, Query.PageValue> {
    InfiniteQueryKey(
      base: .queryState(
        query,
        initialState: InfiniteQueryState(
          initialValue: initialValue,
          initialPageId: query.initialPageId
        ),
        client: client
      )
    )
  }

  public static func infiniteQuery<Query: InfiniteQueryRequest>(
    _ query: DefaultInfiniteQuery<Query>,
    client: QueryClient? = nil
  ) -> Self where Self == InfiniteQueryKey<Query.PageID, Query.PageValue> {
    InfiniteQueryKey(
      base: .queryState(
        query,
        initialState: InfiniteQueryState(
          initialValue: query.defaultValue,
          initialPageId: query.initialPageId
        ),
        client: client
      )
    )
  }

  public static func infiniteQuery<PageID, PageValue>(
    store: QueryStore<InfiniteQueryState<PageID, PageValue>>
  ) -> Self where Self == InfiniteQueryKey<PageID, PageValue> {
    InfiniteQueryKey(base: .queryState(store: store))
  }
}

public struct InfiniteQueryKey<PageID: Hashable & Sendable, PageValue: Sendable> {
  let base: QueryStateKey<InfiniteQueryState<PageID, PageValue>>
}

extension InfiniteQueryKey: SharedKey {
  public typealias Value = SharedInfiniteQueryValue<PageID, PageValue>

  public var id: InfiniteQueryKeyID {
    InfiniteQueryKeyID(inner: self.base.id)
  }

  public func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
    self.base.load(
      context: self.baseContext(for: context),
      continuation: LoadContinuation { result in
        continuation.resume(
          with: result.map {
            SharedInfiniteQueryValue(
              currentValue: $0?.currentValue ?? self.base.store.currentValue,
              store: self.base.store
            )
          }
        )
      }
    )
  }

  public func save(
    _ value: Value,
    context: SaveContext,
    continuation: SaveContinuation
  ) {
    self.base.store.currentValue = value.currentValue
    continuation.resume()
  }

  public func subscribe(
    context: LoadContext<Value>,
    subscriber: SharedSubscriber<Value>
  ) -> SharedSubscription {
    self.base.subscribe(
      context: self.baseContext(for: context),
      subscriber: SharedSubscriber { result in
        subscriber.yield(
          with: result.map {
            SharedInfiniteQueryValue(
              currentValue: $0?.currentValue ?? self.base.store.currentValue,
              store: self.base.store
            )
          }
        )
      } onLoading: {
        subscriber.yieldLoading($0)
      }
    )
  }

  private func baseContext(
    for context: LoadContext<Value>
  ) -> LoadContext<InfiniteQueryState<PageID, PageValue>> {
    switch context {
    case .initialValue: .initialValue(self.base.store.state)
    case .userInitiated: .userInitiated
    }
  }
}

// MARK: - InfiniteQueryKeyID

public struct InfiniteQueryKeyID: Hashable, Sendable {
  fileprivate let inner: QueryStateKeyID
}

// MARK: - SharedInfiniteQueryValue

public struct SharedInfiniteQueryValue<PageID: Hashable & Sendable, PageValue: Sendable>: Sendable {
  public var currentValue: InfiniteQueryPages<PageID, PageValue>
  private let store: QueryStore<InfiniteQueryState<PageID, PageValue>>

  fileprivate init(
    currentValue: InfiniteQueryPages<PageID, PageValue>,
    store: QueryStore<InfiniteQueryState<PageID, PageValue>>
  ) {
    self.currentValue = currentValue
    self.store = store
  }
}

extension SharedInfiniteQueryValue {
  @discardableResult
  public func fetchAllPages(
    using configuration: QueryTaskConfiguration? = nil
  ) async throws -> InfiniteQueryPages<PageID, PageValue> {
    try await self.store.fetchAllPages(using: configuration)
  }

  public func fetchAllPagesTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPages<PageID, PageValue>> {
    self.store.fetchAllPagesTask(using: configuration)
  }
}

extension SharedInfiniteQueryValue {
  @discardableResult
  public func fetchNextPage(
    using configuration: QueryTaskConfiguration? = nil
  ) async throws -> InfiniteQueryPage<PageID, PageValue>? {
    try await store.fetchNextPage(using: configuration)
  }

  public func fetchNextPageTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPage<PageID, PageValue>?> {
    store.fetchNextPageTask(using: configuration)
  }
}

extension SharedInfiniteQueryValue {
  @discardableResult
  public func fetchPreviousPage(
    using configuration: QueryTaskConfiguration? = nil
  ) async throws -> InfiniteQueryPage<PageID, PageValue>? {
    try await store.fetchPreviousPage(using: configuration)
  }

  public func fetchPreviousPageTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPage<PageID, PageValue>?> {
    store.fetchPreviousPageTask(using: configuration)
  }
}

extension SharedInfiniteQueryValue: Equatable where PageValue: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.currentValue == rhs.currentValue
  }
}

extension SharedInfiniteQueryValue: Hashable where PageValue: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(currentValue)
  }
}

// MARK: - Shared Inits

extension Shared {
  public init<PageID, PageValue>(_ key: InfiniteQueryKey<PageID, PageValue>)
  where Value == SharedInfiniteQueryValue<PageID, PageValue> {
    self.init(
      wrappedValue: SharedInfiniteQueryValue(
        currentValue: key.base.store.currentValue,
        store: key.base.store
      ),
      key
    )
  }
}

extension SharedReader {
  public init<PageID, PageValue>(_ key: InfiniteQueryKey<PageID, PageValue>)
  where Value == SharedInfiniteQueryValue<PageID, PageValue> {
    self.init(
      wrappedValue: SharedInfiniteQueryValue(
        currentValue: key.base.store.currentValue,
        store: key.base.store
      ),
      key
    )
  }
}
