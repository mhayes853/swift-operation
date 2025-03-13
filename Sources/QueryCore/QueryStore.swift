import ConcurrencyExtras
import Foundation

// MARK: - Typealiases

public typealias QueryStoreFor<Query: QueryProtocol> = QueryStore<Query.State>

// MARK: - QueryStore

@dynamicMemberLookup
public final class QueryStore<State: QueryStateProtocol>: Sendable {
  private let base: AnyQueryStore

  private init(base: AnyQueryStore) {
    self.base = base
  }

  public init?(casting base: AnyQueryStore) {
    guard base.state.base as? State != nil else {
      return nil
    }
    self.base = base
  }
}

// MARK: - Detached

extension QueryStore {
  public static func detached<Query: QueryProtocol>(
    query: Query,
    initialState: Query.State,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Query> {
    QueryStoreFor<Query>(
      base: .detached(erasing: query, initialState: initialState, initialContext: initialContext)
    )
  }

  public static func detached<Query: QueryProtocol>(
    query: Query,
    initialValue: Query.State.StateValue,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Query> where Query.State == QueryState<Query.Value?, Query.Value> {
    QueryStoreFor<Query>(
      base: .detached(
        erasing: query,
        initialState: Query.State(initialValue: initialValue),
        initialContext: initialContext
      )
    )
  }

  public static func detached<Query: QueryProtocol>(
    query: DefaultQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<DefaultQuery<Query>>
  where DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value> {
    .detached(
      query: query,
      initialState: DefaultQuery<Query>.State(initialValue: query.defaultValue),
      initialContext: initialContext
    )
  }

  public static func detached<Query: InfiniteQueryProtocol>(
    query: Query,
    initialValue: Query.State.StateValue,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Query> {
    .detached(
      query: query,
      initialState: InfiniteQueryState(
        initialValue: initialValue,
        initialPageId: query.initialPageId
      ),
      initialContext: initialContext
    )
  }

  public static func detached<Query: InfiniteQueryProtocol>(
    query: DefaultInfiniteQuery<Query>,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Query> {
    .detached(
      query: query,
      initialState: InfiniteQueryState(
        initialValue: query.defaultValue,
        initialPageId: query.initialPageId
      ),
      initialContext: initialContext
    )
  }

  public static func detached<Mutation: MutationProtocol>(
    mutation: Mutation,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStoreFor<Mutation> {
    .detached(
      query: mutation,
      initialState: MutationState(),
      initialContext: initialContext
    )
  }
}

// MARK: - Path

extension QueryStore {
  public var path: QueryPath {
    self.base.path
  }
}

// MARK: - Context

extension QueryStore {
  public var context: QueryContext {
    get { self.base.context }
    set { self.base.context = newValue }
  }
}

// MARK: - Automatic Fetching

extension QueryStore {
  public var isAutomaticFetchingEnabled: Bool {
    self.base.isAutomaticFetchingEnabled
  }
}

// MARK: - State

extension QueryStore {
  public var state: State {
    self.base.state.base as! State
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<State, NewValue>
  ) -> NewValue {
    self.state[keyPath: keyPath]
  }
}

// MARK: - Fetch

extension QueryStore {
  @discardableResult
  public func fetch(
    handler: QueryEventHandler<State.QueryValue> = QueryEventHandler(),
    using context: QueryContext? = nil
  ) async throws -> State.QueryValue {
    try await self.base.fetch(handler: handler.erased(), using: context) as! State.QueryValue
  }

  @discardableResult
  public func fetchTask(using context: QueryContext? = nil) -> QueryTask<State.QueryValue> {
    self.base.fetchTask(using: context).map { $0 as! State.QueryValue }
  }
}

// MARK: - Subscribe

extension QueryStore {
  public var subscriberCount: Int {
    self.base.subscriberCount
  }

  public func subscribe(
    with handler: QueryEventHandler<State.QueryValue>
  ) -> QuerySubscription {
    self.base.subscribe(with: handler.erased())
  }
}

// MARK: - Access QueryStore In Query

extension QueryProtocol {
  public func currentStore(in context: QueryContext) -> QueryStoreFor<Self>? {
    context.currentStore.flatMap { QueryStoreFor<Self>(casting: $0) }
  }
}

extension QueryContext {
  var currentStore: AnyQueryStore? {
    get { self[CurrentStoreKey.self] }
    set { self[CurrentStoreKey.self] = newValue }
  }

  private enum CurrentStoreKey: Key {
    static var defaultValue: AnyQueryStore? {
      nil
    }
  }
}
