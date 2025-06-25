// MARK: - QueryController

/// A protocol for controlling the state of a query.
///
/// QueryControllers represent reusable and composable pieces of logic that allow one to control
/// thet state of a query, and even automatically refetch a query. You can attach a `QueryController`
/// to a ``QueryRequest`` via the ``QueryRequest/controlled(by:)`` modifier.
///
/// See <doc:UtilizingQueryControllers> to learn more about the best practices and use cases for
/// QueryControllers.
public protocol QueryController<State>: Sendable {
  /// The state type of the query to control.
  associatedtype State: QueryStateProtocol

  /// A method that hands the controls for a query to this controller.
  ///
  /// Here, you can subscribe to any external data sources, or store `controls` inside your
  /// controller for later use. The ``QuerySubscription`` that you return from this method is
  /// responsible for performing any cleanup work involved with `controls`.
  ///
  /// - Parameter controls: A ``QueryControls`` instance.
  /// - Returns: A ``QuerySubscription``.
  func control(with controls: QueryControls<State>) -> QuerySubscription
}

// MARK: - QueryControls

/// A data type for managing  a query's state from within a ``QueryController``.
///
/// You do not create instances of this type. Instead, it is passed to your `QueryController`
/// through ``QueryController/control(with:)``.
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
  /// The current ``QueryContext`` of the query.
  public var context: QueryContext {
    self.store?.context ?? self.defaultContext
  }
}

// MARK: - State

extension QueryControls {
  /// The current state of the query.
  public var state: State {
    self.store?.state ?? self.initialState
  }

  /// Exclusively accesses the controls inside the specified closure.
  ///
  /// The controls are thread-safe, but accessing individual properties without exclusive access can
  /// still lead to high-level data races. Use this method to ensure that your code has exclusive
  /// access to the store when performing multiple property accesses to compute a value or to yield
  /// a new value.
  ///
  /// ```swift
  /// let controls: QueryControls<QueryState<Int, Int>>
  ///
  /// // 🔴 Is prone to high-level data races.
  /// controls.yield(controls.state.currentValue + 1)
  ///
  //  // ✅ No data races.
  /// controls.withExclusiveAccess {
  ///   controls.yield(controls.state.currentValue + 1)
  /// }
  /// ```
  ///
  /// - Parameter fn: A closure with exclusive access to the controls.
  /// - Returns: Whatever `fn` returns.
  public func withExclusiveAccess<T>(_ fn: () throws -> sending T) rethrows -> sending T {
    try self.store?.withExclusiveAccess(fn) ?? (try fn())
  }
}

// MARK: - Is Stale

extension QueryControls {
  /// Whether or not the query is stale.
  public var isStale: Bool {
    self.store?.isStale ?? false
  }
}

// MARK: - Yielding Values

extension QueryControls {
  /// Yields a new result to the query.
  ///
  /// - Parameters:
  ///   - result: The `Result` to yield.
  ///   - context: The ``QueryContext`` to use when yielding.
  public func yield(
    with result: Result<State.StateValue, any Error>,
    using context: QueryContext? = nil
  ) {
    self.store?.setResult(to: result, using: context ?? self.context)
  }

  /// Yields an error to the query.
  ///
  /// - Parameters:
  ///   - error: The `Error` to yield.
  ///   - context: The ``QueryContext`` to use when yielding.
  public func yield(throwing error: Error, using context: QueryContext? = nil) {
    self.yield(with: .failure(error), using: context)
  }

  /// Yields a value to the query.
  ///
  /// - Parameters:
  ///   - value: The value to yield.
  ///   - context: The ``QueryContext`` to use when yielding.
  public func yield(_ value: State.StateValue, using context: QueryContext? = nil) {
    self.yield(with: .success(value), using: context)
  }
}

// MARK: - Refetching

extension QueryControls {
  /// Whether or not you can refetch the query through these controls.
  ///
  /// This property is true when automatic fetching is enabled on the query. See
  /// ``QueryRequest/enableAutomaticFetching(onlyWhen:)`` for more.
  public var canYieldRefetch: Bool {
    self.store?.isAutomaticFetchingEnabled == true
  }

  /// Yields a refetch to the query.
  ///
  /// - Parameter context: The ``QueryContext`` to use for the underlying ``QueryTask``.
  /// - Returns: The result of the refetch, or nil if refetching is unavailable.
  @discardableResult
  public func yieldRefetch(with context: QueryContext? = nil) async throws -> State.QueryValue? {
    try await self.yieldRefetchTask(with: context)?.runIfNeeded()
  }

  /// Creates a ``QueryTask`` to refetch the query.
  ///
  /// - Parameter context: The ``QueryContext`` to use for the ``QueryTask``.
  /// - Returns: A ``QueryTask`` to refetch the query, or nil if refetching is unavailable.
  public func yieldRefetchTask(with context: QueryContext? = nil) -> QueryTask<State.QueryValue>? {
    guard self.canYieldRefetch else { return nil }
    return self.store?.fetchTask(using: context)
  }
}

// MARK: - Subscriber Count

extension QueryControls {
  /// The total number of subscribers for this query.
  public var subscriberCount: Int {
    self.store?.subscriberCount ?? 0
  }
}

// MARK: - Resetting

extension QueryControls {
  /// Yields a reset to the query's state.
  ///
  /// > Important: This will cancel all active ``QueryTask``s on the query. Those cancellations will not be
  /// > reflected in the reset query state.
  ///
  /// - Parameter context: The ``QueryContext`` to yield the reset in.
  public func yieldResetState(using context: QueryContext? = nil) {
    self.store?.resetState(using: context ?? self.context)
  }
}

// MARK: - QueryProtocol

public typealias ControlledQuery<Query: QueryRequest, Controller: QueryController<Query.State>> =
  ModifiedQuery<Query, _QueryControllerModifier<Query, Controller>>

extension QueryRequest {
  /// Attaches a ``QueryController`` to this query.
  ///
  /// - Parameter controller: The controller to attach.
  /// - Returns: A ``ModifiedQuery``.
  public func controlled<Controller: QueryController<State>>(
    by controller: Controller
  ) -> ControlledQuery<Self, Controller> {
    self.modifier(_QueryControllerModifier(controller: controller))
  }
}

public struct _QueryControllerModifier<
  Query: QueryRequest,
  Controller: QueryController<Query.State>
>: _ContextUpdatingQueryModifier {
  let controller: Controller

  public func setup(context: inout QueryContext) {
    context.queryControllers.append(self.controller)
  }
}

// MARK: - QueryContext

extension QueryContext {
  /// The ``QueryController``s attached to a ``QueryRequest``.
  ///
  /// You generally add controllers via the ``QueryRequest/controlled(by:)`` modifier.
  public var queryControllers: [any QueryController] {
    get { self[QueryControllersKey.self] }
    set { self[QueryControllersKey.self] = newValue }
  }

  private enum QueryControllersKey: Key {
    static var defaultValue: [any QueryController] { [] }
  }
}
