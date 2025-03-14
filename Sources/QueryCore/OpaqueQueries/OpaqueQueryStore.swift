import ConcurrencyExtras
import Foundation

// MARK: - QueryStore

@dynamicMemberLookup
public final class OpaqueQueryStore: Sendable {
  private let _base: any OpaqueableQueryStore

  public init(erasing base: QueryStore<some QueryStateProtocol>) {
    self._base = base
  }
}

// MARK: - Base

extension OpaqueQueryStore {
  var base: any Sendable {
    self._base
  }
}

// MARK: - Detached

extension OpaqueQueryStore {
  public static func detached<Query: QueryProtocol>(
    erasing query: Query,
    initialState: Query.State,
    initialContext: QueryContext = QueryContext()
  ) -> OpaqueQueryStore where Query.State.QueryValue == Query.Value {
    OpaqueQueryStore(
      erasing: QueryStoreFor<Query>
        .detached(
          query: query,
          initialState: initialState,
          initialContext: initialContext
        )
    )
  }

  public static func detached<Query: QueryProtocol>(
    erasing query: Query,
    initialValue: Query.State.StateValue,
    initialContext: QueryContext = QueryContext()
  ) -> OpaqueQueryStore
  where Query.State == QueryState<Query.Value?, Query.Value> {
    .detached(
      erasing: query,
      initialState: QueryState(initialValue: initialValue),
      initialContext: initialContext
    )
  }

  public static func detached<Query: QueryProtocol>(
    erasing query: DefaultQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> OpaqueQueryStore
  where
    DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value>
  {
    .detached(
      erasing: query,
      initialState: DefaultQuery<Query>.State(initialValue: query.defaultValue),
      initialContext: initialContext
    )
  }

  public static func detached<Query: InfiniteQueryProtocol>(
    erasing query: Query,
    initialValue: Query.State.StateValue,
    initialContext: QueryContext = QueryContext()
  ) -> OpaqueQueryStore {
    .detached(
      erasing: query,
      initialState: InfiniteQueryState(
        initialValue: initialValue,
        initialPageId: query.initialPageId
      ),
      initialContext: initialContext
    )
  }

  public static func detached<Query: InfiniteQueryProtocol>(
    erasing query: DefaultInfiniteQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> OpaqueQueryStore {
    .detached(
      erasing: query,
      initialState: InfiniteQueryState(
        initialValue: query.defaultValue,
        initialPageId: query.initialPageId
      ),
      initialContext: initialContext
    )
  }

  public static func detached<Mutation: MutationProtocol>(
    erasing mutation: Mutation,
    initialContext: QueryContext = QueryContext()
  ) -> OpaqueQueryStore {
    .detached(
      erasing: mutation,
      initialState: MutationState(),
      initialContext: initialContext
    )
  }
}

// MARK: - Path

extension OpaqueQueryStore {
  public var path: QueryPath {
    self._base.path
  }
}

// MARK: - Context

extension OpaqueQueryStore {
  public var context: QueryContext {
    get { self._base.context }
    set { self._base.context = newValue }
  }
}

// MARK: - Automatic Fetching

extension OpaqueQueryStore {
  public var isAutomaticFetchingEnabled: Bool {
    self.context.enableAutomaticFetchingCondition.isSatisfied(in: self.context)
  }
}

// MARK: - State

extension OpaqueQueryStore {
  public var state: OpaqueQueryState {
    self._base.opaqueState
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<OpaqueQueryState, NewValue>
  ) -> NewValue {
    self.state[keyPath: keyPath]
  }
}

// MARK: - Fetch

extension OpaqueQueryStore {
  @discardableResult
  public func fetch(
    handler: OpaqueQueryEventHandler = QueryEventHandler(),
    using context: QueryContext? = nil
  ) async throws -> any Sendable {
    try await self._base.opaqueFetch(handler: handler, using: context)
  }

  @discardableResult
  public func fetchTask(using context: QueryContext? = nil) -> QueryTask<any Sendable> {
    self._base.opaqueFetchTask(using: context)
  }
}

// MARK: - Subscribe

extension OpaqueQueryStore {
  public var subscriberCount: Int {
    self._base.subscriberCount
  }

  public func subscribe(with handler: OpaqueQueryEventHandler) -> QuerySubscription {
    self._base.opaqueSubscribe(with: handler)
  }
}

// MARK: - OpaquableQueryStore

private protocol OpaqueableQueryStore: Sendable {
  var opaqueState: OpaqueQueryState { get }
  var isAutomaticFetchingEnabled: Bool { get }
  var path: QueryPath { get }
  var context: QueryContext { get nonmutating set }
  var subscriberCount: Int { get }

  func opaqueFetch(
    handler: OpaqueQueryEventHandler,
    using context: QueryContext?
  ) async throws -> any Sendable

  func opaqueFetchTask(using context: QueryContext?) -> QueryTask<any Sendable>

  func opaqueSubscribe(
    with handler: OpaqueQueryEventHandler
  ) -> QuerySubscription
}

extension QueryStore: OpaqueableQueryStore {
  var opaqueState: OpaqueQueryState { OpaqueQueryState(self.state) }

  func opaqueFetch(
    handler: OpaqueQueryEventHandler,
    using context: QueryContext?
  ) async throws -> any Sendable {
    try await self.fetch(handler: handler.casted(to: State.QueryValue.self), using: context)
  }

  func opaqueFetchTask(using context: QueryContext?) -> QueryTask<any Sendable> {
    self.fetchTask(using: context).map { $0 as any Sendable }
  }

  func opaqueSubscribe(
    with handler: OpaqueQueryEventHandler
  ) -> QuerySubscription {
    self.subscribe(with: handler.casted(to: State.QueryValue.self))
  }
}
