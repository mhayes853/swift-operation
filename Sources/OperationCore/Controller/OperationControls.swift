// MARK: - OperationControls

/// A data type for managing  a query's state from within a ``OperationController``.
///
/// You do not create instances of this type. Instead, it is passed to your `OperationController`
/// through ``OperationController/control(with:)``.
public struct OperationControls<State: OperationState>: Sendable {
  private weak var _store: OperationStore<State>?
  private let defaultContext: OperationContext
  private let initialState: State

  init(store: OperationStore<State>, defaultContext: OperationContext, initialState: State) {
    self._store = store
    self.defaultContext = defaultContext
    self.initialState = initialState
  }
}

// MARK: - Context

extension OperationControls {
  /// The current ``OperationContext`` of the query.
  public var context: OperationContext {
    self.store?.context ?? self.defaultContext
  }
}

// MARK: - State

extension OperationControls {
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
  /// let controls: OperationControls<QueryState<Int, Int>>
  ///
  /// // 🔴 Is prone to high-level data races.
  /// controls.yield(controls.state.currentValue + 1)
  ///
  //  // ✅ No data races.
  /// controls.withExclusiveAccess {
  ///   $0.yield($0.state.currentValue + 1)
  /// }
  /// ```
  ///
  /// - Parameter fn: A closure with exclusive access to the controls.
  /// - Returns: Whatever `fn` returns.
  public func withExclusiveAccess<T>(
    _ fn: (Self) throws -> sending T
  ) rethrows -> sending T {
    try self.store?.withExclusiveAccess { _ in try fn(self) } ?? (try fn(self))
  }
}

// MARK: - Is Stale

extension OperationControls {
  /// Whether or not the query is stale.
  public var isStale: Bool {
    self.store?.isStale ?? false
  }
}

// MARK: - Yielding Values

extension OperationControls {
  /// Yields a new result to the query.
  ///
  /// - Parameters:
  ///   - result: The `Result` to yield.
  ///   - context: The ``OperationContext`` to use when yielding.
  public func yield(
    with result: Result<State.StateValue, any Error>,
    using context: OperationContext? = nil
  ) {
    self.store?.setResult(to: result, using: context ?? self.context)
  }

  /// Yields an error to the query.
  ///
  /// - Parameters:
  ///   - error: The `Error` to yield.
  ///   - context: The ``OperationContext`` to use when yielding.
  public func yield(throwing error: Error, using context: OperationContext? = nil) {
    self.yield(with: .failure(error), using: context)
  }

  /// Yields a value to the query.
  ///
  /// - Parameters:
  ///   - value: The value to yield.
  ///   - context: The ``OperationContext`` to use when yielding.
  public func yield(_ value: State.StateValue, using context: OperationContext? = nil) {
    self.yield(with: .success(value), using: context)
  }
}

// MARK: - Refetching

extension OperationControls {
  /// Whether or not you can refetch the query through these controls.
  ///
  /// This property is true when automatic fetching is enabled on the query. See
  /// ``QueryRequest/enableAutomaticFetching(onlyWhen:)`` for more.
  public var canYieldRefetch: Bool {
    self.store?.isAutomaticFetchingEnabled == true
  }

  /// Yields a refetch to the query.
  ///
  /// - Parameter context: The ``OperationContext`` to use for the underlying ``OperationTask``.
  /// - Returns: The result of the refetch, or nil if refetching is unavailable.
  @discardableResult
  public func yieldRefetch(
    with context: OperationContext? = nil
  ) async throws -> State.OperationValue? {
    try await self.yieldRefetchTask(with: context)?.runIfNeeded()
  }

  /// Creates a ``OperationTask`` to refetch the query.
  ///
  /// - Parameter context: The ``OperationContext`` to use for the ``OperationTask``.
  /// - Returns: A ``OperationTask`` to refetch the query, or nil if refetching is unavailable.
  public func yieldRefetchTask(
    with context: OperationContext? = nil
  ) -> OperationTask<State.OperationValue, any Error>? {
    guard self.canYieldRefetch else { return nil }
    return self.store?.runTask(using: context)
  }
}

// MARK: - Subscriber Count

extension OperationControls {
  /// The total number of subscribers for this query.
  public var subscriberCount: Int {
    self.store?.subscriberCount ?? 0
  }
}

// MARK: - Resetting

extension OperationControls {
  /// Yields a reset to the query's state.
  ///
  /// > Important: This will cancel all active ``OperationTask``s on the query. Those cancellations will not be
  /// > reflected in the reset query state.
  ///
  /// - Parameter context: The ``OperationContext`` to yield the reset in.
  public func yieldResetState(using context: OperationContext? = nil) {
    self.store?.resetState(using: context ?? self.context)
  }
}

// MARK: - Store

extension OperationControls {
  private var store: OperationStore<State>? {
    guard let _store else {
      reportWarning(.controllerDeallocatedStoreAccess(stateType: State.self))
      return nil
    }
    return _store
  }
}

// MARK: - Warnings

extension OperationWarning {
  public static func controllerDeallocatedStoreAccess(stateType: Any.Type) -> Self {
    """
    An instance of `OperationStore<\(typeName(stateType))>` has been deallocated, but an access has \
    been attempted from through a `OperationController`.

    This is considered an application programming error, because the lifetime of the \
    `OperationControls` passed to the controller is managed by the store. To fix this, ensure that the \
    `OperationSubscription` returned from your controller's `control` implementation disposes of the \
    `OperationControls` instance passed to it.

        final class MyController<State: OperationState>: OperationController {
          private let controls = Mutex<OperationControls<State>?>(nil)

          func control(with controls: OperationControls<State>) -> OperationSubscription {
            self.controls.withLock { $0 = controls }

            // ...

            return OperationSubscription {
              // Dispose of the controls.
              self.controls.withLock { $0 = nil }
            }
          }
        }
    """
  }
}
