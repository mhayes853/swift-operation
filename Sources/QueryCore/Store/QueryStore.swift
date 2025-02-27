import ConcurrencyExtras
import Foundation

// MARK: - QueryStoreOf

public typealias QueryStoreOf<Query: QueryProtocol> = QueryStore<Query._StateValue, Query.Value>

// MARK: - QueryStore

@dynamicMemberLookup
public final class QueryStore<StateValue: Sendable, EventValue: Sendable>: Sendable {
  private let base: AnyQueryStore

  init(_ type: StateValue.Type, base: AnyQueryStore) {
    self.base = base
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
  public var subscriberCount: Int {
    self.base.subscriberCount
  }

  public func subscribe(
    with eventHandler: QueryStoreEventHandler<EventValue>
  ) -> QueryStoreSubscription {
    self.base.subscribe(with: eventHandler.unsafeCasted(to: (any Sendable).self))
  }
}
