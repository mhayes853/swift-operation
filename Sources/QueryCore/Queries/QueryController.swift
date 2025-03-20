// MARK: - QueryController

public protocol QueryController<State>: Sendable {
  associatedtype State: QueryStateProtocol

  func control(with controls: QueryControls<State>) -> QuerySubscription
}

// MARK: - QueryControls

public struct QueryControls<State: QueryStateProtocol>: Sendable {
  private var _context: @Sendable () -> QueryContext
  private let onResult: @Sendable (Result<State.StateValue, any Error>, QueryContext) -> Void
  private let refetchTask: @Sendable (_ name: String?, QueryContext) -> QueryTask<State.QueryValue>?

  public init(
    context: @escaping @Sendable () -> QueryContext,
    onResult: @escaping @Sendable (Result<State.StateValue, any Error>, QueryContext) -> Void,
    refetchTask: @escaping @Sendable (String?, QueryContext) -> QueryTask<State.QueryValue>?
  ) {
    self._context = context
    self.onResult = onResult
    self.refetchTask = refetchTask
  }
}

extension QueryControls {
  public var context: QueryContext {
    self._context()
  }
}

// MARK: - Yielding Values

extension QueryControls {
  public func yield(
    with result: Result<State.StateValue, any Error>,
    using context: QueryContext? = nil
  ) {
    self.onResult(result, context ?? self.context)
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
  @discardableResult
  public func yieldRefetch(
    taskName: String? = nil,
    using context: QueryContext? = nil
  ) async throws -> State.QueryValue? {
    try await self.yieldRefetchTask(name: taskName, using: context)?.runIfNeeded()
  }

  public func yieldRefetchTask(
    name: String? = nil,
    using context: QueryContext? = nil
  ) -> QueryTask<State.QueryValue>? {
    self.refetchTask(name, context ?? self.context)
  }
}

// MARK: - QueryProtocol

extension QueryProtocol {
  public func controlled(
    by controller: some QueryController<State>
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(QueryControllerModifier(controller: controller))
  }
}

private struct QueryControllerModifier<
  Query: QueryProtocol,
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
  public fileprivate(set) var queryControllers: [any QueryController] {
    get { self[QueryControllersKey.self] }
    set { self[QueryControllersKey.self] = newValue }
  }

  private enum QueryControllersKey: Key {
    static var defaultValue: [any QueryController] { [] }
  }
}
