// MARK: - QueryController

public protocol QueryController<Query>: Sendable {
  associatedtype Query: QueryProtocol

  func control(with controls: QueryControls<Query>) -> QuerySubscription
}

// MARK: - QueryControls

public struct QueryControls<Query: QueryProtocol>: Sendable {
  public var context: QueryContext
  private let onResult: @Sendable (Result<Query.State.StateValue, any Error>, QueryContext) -> Void
  private let refetchTask:
    @Sendable (_ name: String?, QueryContext) -> QueryTask<Query.State.QueryValue>?

  public init(
    context: QueryContext,
    onResult: @escaping @Sendable (Result<Query.State.StateValue, any Error>, QueryContext) -> Void,
    refetchTask: @escaping @Sendable (String?, QueryContext) -> QueryTask<Query.State.QueryValue>?
  ) {
    self.context = context
    self.onResult = onResult
    self.refetchTask = refetchTask
  }
}

// MARK: - Yielding Values

extension QueryControls {
  public func yield(
    with result: Result<Query.State.StateValue, any Error>,
    using context: QueryContext? = nil
  ) {
    self.onResult(result, context ?? self.context)
  }

  public func yield(throwing error: Error, using context: QueryContext? = nil) {
    self.yield(with: .failure(error), using: context)
  }

  public func yield(_ value: Query.State.StateValue, using context: QueryContext? = nil) {
    self.yield(with: .success(value), using: context)
  }
}

// MARK: - Refetching

extension QueryControls {
  @discardableResult
  public func yieldRefetch(
    taskName: String? = nil,
    using context: QueryContext? = nil
  ) async throws -> Query.State.QueryValue? {
    try await self.yieldRefetchTask(name: taskName, using: context)?.runIfNeeded()
  }

  public func yieldRefetchTask(
    name: String? = nil,
    using context: QueryContext? = nil
  ) -> QueryTask<Query.State.QueryValue>? {
    self.refetchTask(name, context ?? self.context)
  }
}

// MARK: - QueryProtocol

extension QueryProtocol {
  public func controlled(
    by controller: some QueryController<Self>
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(QueryControllerModifier(controller: controller))
  }
}

private struct QueryControllerModifier<
  Query: QueryProtocol,
  Controller: QueryController<Query>
>: QueryModifier {
  let controller: Controller

  func setup(context: inout QueryContext, using query: Query) {
    context.queryControllers.append(self.controller)
    query.setup(context: &context)
  }

  func fetch(in context: QueryContext, using query: Query) async throws -> Query.Value {
    try await query.fetch(in: context)
  }
}

// MARK: - QueryContext

extension QueryContext {
  public fileprivate(set) var queryControllers: [any QueryController] {
    get { self[QueryControllersKey.self] }
    set { self[QueryControllersKey.self] = newValue }
  }

  private enum QueryControllersKey: Key {
    static var defaultValue: [any QueryController] {
      []
    }
  }
}
