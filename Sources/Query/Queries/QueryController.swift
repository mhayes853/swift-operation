// MARK: - QueryController

public protocol QueryController<State>: Sendable {
  associatedtype State: QueryStateProtocol

  func control(with controls: QueryControls<State>) -> QuerySubscription
}

// MARK: - QueryControls

public struct QueryControls<State: QueryStateProtocol>: Sendable {
  private weak var store: QueryStore<State>?
  private let defaultContext: QueryContext
  private let initialState: State

  init(store: QueryStore<State>, defaultContext: QueryContext, initialState: State) {
    self.store = store
    self.defaultContext = defaultContext
    self.initialState = initialState
  }
}

// MARK: - Context

extension QueryControls {
  public var context: QueryContext {
    self.store?.context ?? self.defaultContext
  }
}

// MARK: - State

extension QueryControls {
  public var state: State {
    self.store?.state ?? self.initialState
  }

  public func withState<T: Sendable>(_ fn: (State) throws -> T) rethrows -> T {
    try self.store?.withState(fn) ?? (try fn(self.initialState))
  }
}

// MARK: - Is Stale

extension QueryControls {
  public var isStale: Bool {
    self.store?.isStale ?? false
  }

  public func isStale(using context: QueryContext? = nil) -> Bool {
    self.store?.isStale(using: context) ?? false
  }
}

// MARK: - Yielding Values

extension QueryControls {
  public func yield(
    with result: Result<State.StateValue, any Error>,
    using context: QueryContext? = nil
  ) {
    self.store?.setResult(to: result, using: context ?? self.context)
  }

  public func yield(throwing error: Error, using context: QueryContext? = nil) {
    self.yield(with: .failure(error), using: context)
  }

  public func yield(_ value: State.StateValue, using context: QueryContext? = nil) {
    self.yield(with: .success(value), using: context)
  }
}

// MARK: - Refetching

extension QueryControls {
  public var canYieldRefetch: Bool {
    self.store?.isAutomaticFetchingEnabled == true
  }

  @discardableResult
  public func yieldRefetch(
    with configuration: QueryTaskConfiguration? = nil
  ) async throws -> State.QueryValue? {
    try await self.yieldRefetchTask(with: configuration)?.runIfNeeded()
  }

  public func yieldRefetchTask(
    with configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<State.QueryValue>? {
    guard self.canYieldRefetch else { return nil }
    return self.store?.fetchTask(using: configuration)
  }
}

// MARK: - Resetting

extension QueryControls {
  public func yieldReset(using context: QueryContext? = nil) {
    self.store?.reset(using: context ?? self.context)
  }
}

// MARK: - QueryProtocol

extension QueryRequest {
  public func controlled(
    by controller: some QueryController<State>
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(QueryControllerModifier(controller: controller))
  }
}

private struct QueryControllerModifier<
  Query: QueryRequest,
  Controller: QueryController<Query.State>
>: QueryModifier {
  let controller: Controller

  func setup(context: inout QueryContext, using query: Query) {
    context.queryControllers.append(self.controller)
    query.setup(context: &context)
  }

  func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await query.fetch(in: context, with: continuation)
  }
}

// MARK: - QueryContext

extension QueryContext {
  public var queryControllers: [any QueryController] {
    get { self[QueryControllersKey.self] }
    set { self[QueryControllersKey.self] = newValue }
  }

  private enum QueryControllersKey: Key {
    static var defaultValue: [any QueryController] { [] }
  }
}
