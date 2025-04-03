import Dependencies
import Foundation
import IdentifiedCollections
import Query
import Sharing

// MARK: - QueryStateKey

extension SharedReaderKey {
  public static func queryState<Query: QueryRequest>(
    _ query: Query,
    initialValue: Query.State.StateValue,
    client: QueryClient? = nil
  ) -> Self
  where Self == QueryStateKey<Query.State>, Query.State == QueryState<Query.Value?, Query.Value> {
    .queryState(query, initialState: QueryState(initialValue: initialValue), client: client)
  }

  public static func queryState<Query: QueryRequest>(
    _ query: DefaultQuery<Query>,
    client: QueryClient? = nil
  ) -> Self where Self == QueryStateKey<DefaultQuery<Query>.State> {
    .queryState(query, initialState: QueryState(initialValue: query.defaultValue), client: client)
  }

  public static func infiniteQueryState<Query: InfiniteQueryRequest>(
    _ query: Query,
    initialValue: Query.State.StateValue = [],
    client: QueryClient? = nil
  ) -> Self where Self == QueryStateKey<InfiniteQueryState<Query.PageID, Query.PageValue>> {
    .queryState(
      query,
      initialState: InfiniteQueryState(
        initialValue: initialValue,
        initialPageId: query.initialPageId
      ),
      client: client
    )
  }

  public static func infiniteQueryState<Query: InfiniteQueryRequest>(
    _ query: DefaultInfiniteQuery<Query>,
    client: QueryClient? = nil
  ) -> Self where Self == QueryStateKey<InfiniteQueryState<Query.PageID, Query.PageValue>> {
    .queryState(
      query,
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
  >(_ mutation: Mutation, client: QueryClient? = nil) -> Self
  where Self == QueryStateKey<MutationState<Arguments, Value>> {
    .queryState(mutation, initialState: MutationState(), client: client)
  }

  public static func queryState<Query: QueryRequest>(
    _ query: Query,
    initialState: Query.State,
    client: QueryClient? = nil
  ) -> Self
  where Self == QueryStateKey<Query.State>, Query.State.QueryValue == Query.Value {
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
  public let id = QueryStateKeyID()

  public init(store: QueryStore<State>) {
    self.store = store
  }
}

extension QueryStateKey: SharedReaderKey {
  public func load(context: LoadContext<State>, continuation: LoadContinuation<State>) {
    switch context {
    case .initialValue:
      continuation.resume(returning: self.store.state)
    case .userInitiated:
      Task<Void, Never> {
        do {
          try await self.store.fetch()
          continuation.resume(returning: self.store.state)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  public func subscribe(
    context: LoadContext<State>,
    subscriber: SharedSubscriber<State>
  ) -> SharedSubscription {
    let subscription = self.store.subscribe(
      with: QueryEventHandler { state, _ in
        subscriber.yield(state)
        if let error = state.error {
          subscriber.yield(throwing: error)
        }
        subscriber.yieldLoading(state.isLoading)
      }
    )
    return SharedSubscription { subscription.cancel() }
  }
}

// MARK: - QueryStateKeyID

public struct QueryStateKeyID: Sendable {
  fileprivate let inner = Inner()
}

extension QueryStateKeyID {
  fileprivate final class Inner: Sendable {}
}

extension QueryStateKeyID: Equatable {
  public static func == (lhs: QueryStateKeyID, rhs: QueryStateKeyID) -> Bool {
    lhs.inner === rhs.inner
  }
}

extension QueryStateKeyID: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(inner))
  }
}

// MARK: - SharedReader Init

extension SharedReader where Value: QueryStateProtocol {
  public init(_ key: QueryStateKey<Value>) {
    self.init(wrappedValue: key.store.state, key)
  }
}
