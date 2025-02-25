import ConcurrencyExtras
import Foundation

// MARK: - QueryStoreOf

public typealias QueryStoreOf<Query: QueryProtocol> = QueryStore<Query.Value?, Query.Value>

// MARK: - DefaultQueryStoreOf

public typealias DefaultQueryStoreOf<Query: QueryProtocol> = QueryStore<Query.Value, Query.Value>

// MARK: - QueryStore

@dynamicMemberLookup
public final class QueryStore<StateValue: Sendable, EventValue: Sendable>: Sendable {
  private let base: AnyQueryStore

  init(_ type: StateValue.Type, base: AnyQueryStore) {
    self.base = base
  }
}

// MARK: - Path

extension QueryStore {
  public var path: QueryPath {
    self.base.path
  }
}

// MARK: - State

extension QueryStore {
  public var state: QueryState<StateValue> {
    self.base.state.unsafeCasted(to: StateValue.self)
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<QueryState<StateValue>, NewValue>
  ) -> NewValue {
    self.state[keyPath: keyPath]
  }
}

// MARK: - Fetching

extension QueryStore {
  @discardableResult
  public func fetch() async throws -> StateValue {
    try await self.base.fetch() as! StateValue
  }
}

// MARK: - Subscribe

extension QueryStore {
  public func subscribe(
    _ fn: @escaping QueryStoreSubscriber<EventValue>
  ) -> QueryStoreSubscription {
    self.base.subscribe { _ in }
  }
}
