import IdentifiedCollections
import Perception
import QueryCore
import SwiftNavigation

#if canImport(SwiftUI)
  import SwiftUI
#endif

// MARK: - QueryModel

@Perceptible
@MainActor
@dynamicMemberLookup
public final class QueryModel<State: QueryStateProtocol> {
  public private(set) var state: State

  public let store: QueryStore<State>

  private var subscription = QuerySubscription.empty

  #if canImport(SwiftUI)
    public var transaction = Transaction()
  #endif

  public var uiTransaction = UITransaction()

  public init(store: QueryStore<State>) {
    self.store = store
    self.state = store.state
    self.subscription = store.subscribe(
      with: QueryEventHandler { [weak self] state, _ in
        Task { @MainActor in
          guard let self else { return }
          self.withTransaction { self.state = state }
        }
      }
    )
  }
}

// MARK: - UITransaction Init

extension QueryModel {
  public convenience init(store: QueryStore<State>, uiTransaction: UITransaction) {
    self.init(store: store)
    self.uiTransaction = uiTransaction
  }
}

// MARK: - Dynamic Member Lookup

extension QueryModel {
  public var currentValue: State.StateValue {
    get { self.state.currentValue }
    set { self.store.currentValue = newValue }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.state[keyPath: keyPath]
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<QueryStore<State>, Value>) -> Value {
    self.store[keyPath: keyPath]
  }
}

// MARK: - State Functions

extension QueryModel {
  public func setResult(
    to result: Result<State.StateValue, any Error>,
    using context: QueryContext? = nil
  ) {
    self.store.setResult(to: result, using: context)
  }

  public func reset(using context: QueryContext? = nil) {
    self.store.reset(using: context)
  }
}

// MARK: - Is Stale

extension QueryModel {
  public func isStale(using context: QueryContext? = nil) -> Bool {
    self.store.isStale(using: context)
  }
}

// MARK: - Fetch

extension QueryModel {
  public func fetch(
    using configuration: QueryTaskConfiguration? = nil,
    handler: QueryEventHandler<State> = QueryEventHandler()
  ) async throws -> State.QueryValue {
    try await self.store.fetch(using: configuration, handler: handler)
  }

  public func fetchTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<State.QueryValue> {
    self.store.fetchTask(using: configuration)
  }
}

extension QueryModel where State: _InfiniteQueryStateProtocol {
  @discardableResult
  public func fetchAllPages(
    using configuration: QueryTaskConfiguration? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPages<State.PageID, State.PageValue> {
    try await self.store.fetchAllPages(using: configuration, handler: handler)
  }

  public func fetchAllPagesTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPages<State.PageID, State.PageValue>> {
    self.store.fetchAllPagesTask(using: configuration)
  }

  @discardableResult
  public func fetchNextPage(
    using configuration: QueryTaskConfiguration? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    try await self.store.fetchNextPage(using: configuration, handler: handler)
  }

  public func fetchNextPageTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPage<State.PageID, State.PageValue>?> {
    self.store.fetchNextPageTask(using: configuration)
  }

  @discardableResult
  public func fetchPreviousPage(
    using configuration: QueryTaskConfiguration? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    try await self.store.fetchPreviousPage(using: configuration, handler: handler)
  }

  public func fetchPreviousPageTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPage<State.PageID, State.PageValue>?> {
    self.store.fetchPreviousPageTask(using: configuration)
  }
}

extension QueryModel where State: _MutationStateProtocol {
  @discardableResult
  public func mutate(
    with arguments: State.Arguments,
    using configuration: QueryTaskConfiguration? = nil,
    handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
  ) async throws -> State.Value {
    try await self.store.mutate(with: arguments, using: configuration, handler: handler)
  }

  public func mutateTask(
    with arguments: State.Arguments,
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<State.Value> {
    self.store.mutateTask(with: arguments, using: configuration)
  }

  @discardableResult
  public func retryLatest(
    using configuration: QueryTaskConfiguration? = nil,
    handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
  ) async throws -> State.Value {
    try await self.store.retryLatest(using: configuration, handler: handler)
  }

  public func retryLatestTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<State.Value> {
    self.store.retryLatestTask(using: configuration)
  }
}

// MARK: - SwiftUI

#if canImport(SwiftUI)
  extension QueryModel {
    public var animation: Animation? {
      get { self.transaction.animation }
      set { self.transaction.animation = newValue }
    }

    public convenience init(store: QueryStore<State>, animation: Animation?) {
      self.init(store: store)
      self.animation = animation
    }

    public convenience init(store: QueryStore<State>, transaction: Transaction) {
      self.init(store: store)
      self.transaction = transaction
    }
  }
#endif

// MARK: - WithTransaction

extension QueryModel {
  private func withTransaction(_ body: () -> Void) {
    withUITransaction(self.uiTransaction) {
      #if canImport(SwiftUI)
        SwiftUI.withTransaction(self.transaction) {
          body()
        }
      #else
        body()
      #endif
    }
  }
}
