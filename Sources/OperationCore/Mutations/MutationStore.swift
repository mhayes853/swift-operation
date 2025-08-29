// MARK: - Detached

extension OperationStore {
  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``OperationClient``. As such, accessing the
  /// ``OperationContext/OperationClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - mutation: The ``MutationRequest``.
  ///   - initialContext: The default ``OperationContext``.
  /// - Returns: A store.
  public static func detached<Mutation: MutationRequest>(
    mutation: Mutation.Default,
    initialContext: OperationContext = OperationContext()
  ) -> OperationStore<Mutation.Default.State> where State == DefaultOperation<Mutation>.State {
    .detached(
      operation: mutation,
      initialState: mutation.initialState,
      initialContext: initialContext
    )
  }

  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``OperationClient``. As such, accessing the
  /// ``OperationContext/OperationClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - mutation: The ``MutationRequest``.
  ///   - initialValue: The initial value.
  ///   - initialContext: The default ``OperationContext``.
  /// - Returns: A store.
  public static func detached<Mutation: MutationRequest>(
    mutation: Mutation,
    initialValue: Mutation.ReturnValue? = nil,
    initialContext: OperationContext = OperationContext()
  ) -> OperationStore<Mutation.State>
  where State == MutationState<Mutation.Arguments, Mutation.ReturnValue> {
    .detached(
      operation: mutation,
      initialState: Mutation.State(initialValue: initialValue),
      initialContext: initialContext
    )
  }

  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``OperationClient``. As such, accessing the
  /// ``OperationContext/OperationClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - mutation: The ``MutationRequest``.
  ///   - initialState: The initial state.
  ///   - initialContext: The default ``OperationContext``.
  /// - Returns: A store.
  public static func detached<Mutation: MutationRequest>(
    mutation: Mutation,
    initialState: Mutation.State,
    initialContext: OperationContext = OperationContext()
  ) -> OperationStore<Mutation.State>
  where State == MutationState<Mutation.Arguments, Mutation.ReturnValue> {
    .detached(
      operation: mutation,
      initialState: initialState,
      initialContext: initialContext
    )
  }
}

// MARK: - Mutate

extension OperationStore where State: _MutationStateProtocol {
  /// Performs a mutation.
  ///
  /// - Parameters:
  ///   - arguments: The set of arguments to mutate with.
  ///   - context: The ``OperationContext`` used by the underlying ``OperationTask``.
  ///   - handler: A ``QueryEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func mutate(
    with arguments: State.Arguments,
    using context: OperationContext? = nil,
    handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
  ) async throws(State.Failure) -> State.Value {
    try await self.run(
      using: self.taskConfiguration(with: arguments, using: context),
      handler: self.operationEventHandler(for: handler)
    )
    .returnValue
  }

  /// Creates a ``OperationTask`` that performs a mutation.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``OperationTask/runIfNeeded()`` to fetch the data.
  ///
  /// - Parameters:
  ///   - arguments: The set of arguments to mutate with.
  ///   - context: The ``OperationContext`` for the task.
  /// - Returns: A task to perform the mutation.
  public func mutateTask(
    with arguments: State.Arguments,
    using context: OperationContext? = nil
  ) -> OperationTask<State.Value, State.Failure> {
    self.runTask(using: self.taskConfiguration(with: arguments, using: context))
      .map(\.returnValue)
  }

  private func taskConfiguration(
    with arguments: State.Arguments,
    using base: OperationContext?
  ) -> OperationContext {
    var context = base ?? self.context
    context.mutationValues.arguments = arguments
    context.operationTaskConfiguration.name =
      context.operationTaskConfiguration.name ?? self.mutateTaskName
    return context
  }

  private var mutateTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Mutate Task"
  }
}

extension OperationStore where State: _MutationStateProtocol, State.Arguments == Void {
  /// Performs a mutation with no arguments.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` used by the underlying ``OperationTask``.
  ///   - handler: A ``MutationEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func mutate(
    using context: OperationContext? = nil,
    handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
  ) async throws(State.Failure) -> State.Value {
    try await self.mutate(with: (), using: context, handler: handler)
  }

  /// Creates a ``OperationTask`` that performs a mutation with no arguments.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``OperationTask/runIfNeeded()`` to fetch the data.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` for the task.
  /// - Returns: A task to perform the mutation.
  public func mutateTask(
    using context: OperationContext? = nil
  ) -> OperationTask<State.Value, State.Failure> {
    self.mutateTask(with: (), using: context)
  }
}

// MARK: - Retry Latest

extension OperationStore where State: _MutationStateProtocol {
  /// Retries the mutation with the most recently used set of arguments.
  ///
  /// > Important: Calling this method without previously having called ``mutate(using:handler:)``
  /// > will result in a purple runtime warning in Xcode, and a test failure for current running
  /// > test. Additionally, the mutation will also throw an error.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` used by the underlying ``OperationTask``.
  ///   - handler: A ``MutationEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func retryLatest(
    using context: OperationContext? = nil,
    handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
  ) async throws(State.Failure) -> State.Value {
    try await self.run(
      using: self.retryTaskConfiguration(using: context),
      handler: self.operationEventHandler(for: handler)
    )
    .returnValue
  }

  /// Creates a ``OperationTask`` that retries the mutation with the most recently used set of
  /// arguments.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``OperationTask/runIfNeeded()`` to fetch the data.
  ///
  /// > Important: Calling this method without previously having called ``mutate(using:handler:)``
  /// > will result in a purple runtime warning in Xcode, and a test failure for current running
  /// > test. Additionally, the mutation will also throw an error.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` for the task.
  /// - Returns: A task to retry the most recently used arguments on the mutation.
  public func retryLatestTask(
    using context: OperationContext? = nil
  ) -> OperationTask<State.Value, State.Failure> {
    self.runTask(using: self.retryTaskConfiguration(using: context)).map(\.returnValue)
  }

  private func retryTaskConfiguration(
    using base: OperationContext?
  ) -> OperationContext {
    var context = base ?? self.context
    context.operationTaskConfiguration.name =
      context.operationTaskConfiguration.name ?? self.retryLatestTaskName
    return context
  }

  private var retryLatestTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Retry Latest Task"
  }
}

// MARK: - Subscribe

extension OperationStore where State: _MutationStateProtocol {
  /// Subscribes to events from this store using a ``MutationEventHandler``.
  ///
  /// - Parameter handler: The event handler.
  /// - Returns: A ``OperationSubscription``.
  public func subscribe(
    with handler: MutationEventHandler<State.Arguments, State.Value>
  ) -> OperationSubscription {
    self.subscribe(with: self.operationEventHandler(for: handler))
  }
}

// MARK: - Event Handler

extension OperationStore where State: _MutationStateProtocol {
  private func operationEventHandler(
    for handler: MutationEventHandler<State.Arguments, State.Value>
  ) -> OperationEventHandler<State> {
    OperationEventHandler(
      onStateChanged: {
        handler.onStateChanged?($0 as! MutationState<State.Arguments, State.Value>, $1)
      },
      onFetchingStarted: {
        guard let args = $0.mutationArgs(as: State.Arguments.self) else { return }
        handler.onMutatingStarted?(args, $0)
      },
      onFetchingEnded: {
        guard let args = $0.mutationArgs(as: State.Arguments.self) else { return }
        handler.onMutatingEnded?(args, $0)
      },
      onResultReceived: {
        guard let args = $1.mutationArgs(as: State.Arguments.self) else { return }
        handler.onMutationResultReceived?(args, $0.map(\.returnValue), $1)
      }
    )
  }
}
