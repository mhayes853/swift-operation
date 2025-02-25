import ConcurrencyExtras
import Foundation

// MARK: - QueryStore

@dynamicMemberLookup
public final class QueryStore<Value: Sendable>: Sendable {
  private let base: AnyQueryStore

  init(_ type: Value.Type, base: AnyQueryStore) {
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
  public var state: QueryState<Value> {
    self.base.state.unsafeCasted(to: Value.self)
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<QueryState<Value>, NewValue>
  ) -> NewValue {
    self.state[keyPath: keyPath]
  }
}

// MARK: - Fetching

extension QueryStore {
  @discardableResult
  public func fetch() async throws -> Value {
    try await self.base.fetch() as! Value
  }
}

// MARK: - Subscribe

extension QueryStore {
  public func subscribe(
    _ fn: @escaping QueryStoreSubscriber<Value>
  ) -> QueryStoreSubscription {
    self.base.subscribe { _ in }
  }
}
