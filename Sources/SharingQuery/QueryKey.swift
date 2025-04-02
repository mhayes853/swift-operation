import Dependencies
import Query
import Sharing

// MARK: - QueryKey

extension SharedKey {
  public static func query<Query: QueryRequest>(
    _ query: Query,
    initialValue: Query.State.StateValue,
    client: QueryClient? = nil
  ) -> Self
  where Self == QueryKey<Query.State>, Query.State == QueryState<Query.Value?, Query.Value> {
    .query(query, initialState: QueryState(initialValue: initialValue), client: client)
  }

  public static func query<Query: QueryRequest>(
    _ query: DefaultQuery<Query>,
    client: QueryClient? = nil
  ) -> Self where Self == QueryKey<DefaultQuery<Query>.State> {
    .query(
      query,
      initialState: QueryState(initialValue: query.defaultValue),
      client: client
    )
  }

  public static func query<Query: QueryRequest>(
    _ query: Query,
    initialState: Query.State,
    client: QueryClient? = nil
  ) -> Self
  where Self == QueryKey<Query.State>, Query.State.QueryValue == Query.Value {
    QueryKey(base: .queryState(query, initialState: initialState, client: client))
  }

  public static func query<State>(store: QueryStore<State>) -> Self where Self == QueryKey<State> {
    QueryKey(base: .queryState(store: store))
  }
}

public struct QueryKey<State: QueryStateProtocol> {
  let base: QueryStateKey<State>
}

extension QueryKey: SharedKey {
  public typealias Value = State.StateValue

  public var id: QueryKeyID {
    QueryKeyID(inner: self.base.id)
  }

  public func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
    self.base.load(
      context: self.baseContext(for: context),
      continuation: LoadContinuation { result in
        continuation.resume(with: result.map { $0?.currentValue })
      }
    )
  }

  public func save(_ value: Value, context: SaveContext, continuation: SaveContinuation) {
    self.base.store.currentValue = value
    continuation.resume()
  }

  public func subscribe(
    context: LoadContext<Value>,
    subscriber: SharedSubscriber<Value>
  ) -> SharedSubscription {
    self.base.subscribe(
      context: self.baseContext(for: context),
      subscriber: SharedSubscriber { result in
        subscriber.yield(with: result.map { $0?.currentValue })
      } onLoading: {
        subscriber.yieldLoading($0)
      }
    )
  }

  private func baseContext(for context: LoadContext<Value>) -> LoadContext<State> {
    switch context {
    case .initialValue: .initialValue(self.base.store.state)
    case .userInitiated: .userInitiated
    }
  }
}

// MARK: - QueryKeyID

public struct QueryKeyID: Hashable {
  fileprivate let inner: QueryStateKeyID
}

// MARK: - Shared Inits

extension Shared {
  public init<State>(_ key: QueryKey<State>) where Value == State.StateValue {
    self.init(wrappedValue: key.base.store.currentValue, key)
  }
}

extension SharedReader {
  public init<State>(_ key: QueryKey<State>) where Value == State.StateValue {
    self.init(wrappedValue: key.base.store.currentValue, key)
  }
}
