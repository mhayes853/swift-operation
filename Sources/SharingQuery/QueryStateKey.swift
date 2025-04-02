import Dependencies
import IdentifiedCollections
import Query
import Sharing

// MARK: - QueryStateKey

extension SharedReaderKey {
  public static func queryState<Query: QueryRequest>(
    query: Query,
    initialValue: Query.State.StateValue,
    client: QueryClient? = nil
  ) -> Self
  where Self == QueryStateKey<Query.State>, Query.State == QueryState<Query.Value?, Query.Value> {
    .queryState(query: query, initialState: QueryState(initialValue: initialValue), client: client)
  }

  public static func queryState<Query: QueryRequest>(
    query: DefaultQuery<Query>,
    client: QueryClient? = nil
  ) -> Self where Self == QueryStateKey<DefaultQuery<Query>.State> {
    .queryState(
      query: query,
      initialState: QueryState(initialValue: query.defaultValue),
      client: client
    )
  }

  public static func infiniteQueryState<Query: InfiniteQueryRequest>(
    query: Query,
    initialValue: Query.State.StateValue = [],
    client: QueryClient? = nil
  ) -> Self where Self == QueryStateKey<InfiniteQueryState<Query.PageID, Query.PageValue>> {
    .queryState(
      query: query,
      initialState: InfiniteQueryState(
        initialValue: initialValue,
        initialPageId: query.initialPageId
      ),
      client: client
    )
  }

  public static func infiniteQueryState<Query: InfiniteQueryRequest>(
    query: DefaultInfiniteQuery<Query>,
    client: QueryClient? = nil
  ) -> Self where Self == QueryStateKey<InfiniteQueryState<Query.PageID, Query.PageValue>> {
    .queryState(
      query: query,
      initialState: InfiniteQueryState(
        initialValue: query.defaultValue,
        initialPageId: query.initialPageId
      ),
      client: client
    )
  }

  public static func mutationState<
    Arguments: Sendable,
    Value: Sendable,
    Mutation: MutationRequest<Arguments, Value>
  >(mutation: Mutation, client: QueryClient? = nil) -> Self
  where Self == QueryStateKey<MutationState<Arguments, Value>> {
    .queryState(query: mutation, initialState: MutationState(), client: client)
  }

  public static func queryState<State, Query: QueryRequest>(
    query: Query,
    initialState: State,
    client: QueryClient? = nil
  ) -> Self
  where Self == QueryStateKey<State>, State == Query.State, State.QueryValue == Query.Value {
    @Dependency(\.queryClient) var queryClient
    return .queryState(store: (client ?? queryClient).store(for: query, initialState: initialState))
  }

  public static func queryState<State>(store: QueryStore<State>) -> Self
  where Self == QueryStateKey<State> {
    QueryStateKey(store: store)
  }
}

public struct QueryStateKey<State: QueryStateProtocol> {
  public let store: QueryStore<State>
}

extension QueryStateKey: SharedReaderKey {
  public var id: QueryStateKeyID {
    QueryStateKeyID(storeIdentifier: ObjectIdentifier(store))
  }

  public func load(context: LoadContext<State>, continuation: LoadContinuation<State>) {

  }

  public func subscribe(
    context: LoadContext<State>,
    subscriber: SharedSubscriber<State>
  ) -> SharedSubscription {
    SharedSubscription {}
  }
}

// MARK: - QueryStateKeyID

public struct QueryStateKeyID: Hashable, Sendable {
  fileprivate let storeIdentifier: ObjectIdentifier
}

// MARK: - SharedReader Init

extension SharedReader where Value: QueryStateProtocol {
  public init(_ key: QueryStateKey<Value>) {
    self.init(wrappedValue: key.store.state, key)
  }
}
