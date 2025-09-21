// MARK: - Detached

extension OperationStore {
  /// Creates a detached store.
  ///
  /// Detached stores are not connected to an ``OperationClient``. As such, accessing the
  /// ``OperationContext/operationClient`` context property in your operation will always yield a nil
  /// value.
  ///
  /// - Parameters:
  ///   - mutation: The ``MutationRequest``.
  ///   - initialContext: The default ``OperationContext``.
  /// - Returns: A store.
  public static func detached<Mutation: MutationRequest>(
    mutation: sending Mutation.Default,
    initialContext: OperationContext = OperationContext()
  ) -> OperationStore<Mutation.Default.State> where State == DefaultStateOperation<Mutation>.State {
    .detached(
      operation: mutation,
      initialState: mutation.initialState,
      initialContext: initialContext
    )
  }

  /// Creates a detached store.
  ///
  /// Detached stores are not connected to an ``OperationClient``. As such, accessing the
  /// ``OperationContext/operationClient`` context property in your operation will always yield a nil
  /// value.
  ///
  /// - Parameters:
  ///   - mutation: The ``MutationRequest``.
  ///   - initialValue: The initial value.
  ///   - initialContext: The default ``OperationContext``.
  /// - Returns: A store.
  public static func detached<Mutation: MutationRequest>(
    mutation: sending Mutation,
    initialValue: Mutation.MutateValue? = nil,
    initialContext: OperationContext = OperationContext()
  ) -> OperationStore<Mutation.State>
  where State == MutationState<Mutation.Arguments, Mutation.MutateValue, Mutation.Failure> {
    .detached(
      operation: mutation,
      initialState: Mutation.State(initialValue: initialValue),
      initialContext: initialContext
    )
  }

  /// Creates a detached store.
  ///
  /// Detached stores are not connected to an ``OperationClient``. As such, accessing the
  /// ``OperationContext/operationClient`` context property in your operation will always yield a nil
  /// value.
  ///
  /// - Parameters:
  ///   - mutation: The ``MutationRequest``.
  ///   - initialState: The initial state.
  ///   - initialContext: The default ``OperationContext``.
  /// - Returns: A store.
  public static func detached<Mutation: MutationRequest>(
    mutation: sending Mutation,
    initialState: Mutation.State,
    initialContext: OperationContext = OperationContext()
  ) -> OperationStore<Mutation.State>
  where State == MutationState<Mutation.Arguments, Mutation.MutateValue, Mutation.Failure> {
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
  ///   - handler: A ``MutationEventHandler`` to subscribe to events during the mutation run.
  ///   (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func mutate(
    with arguments: State.Arguments,
    using context: OperationContext? = nil,
    handler: MutationEventHandler<State> = MutationEventHandler()
  ) async throws(State.Failure) -> State.Value {
    try await self.run(
      using: self.taskConfiguration(with: arguments, using: context),
      handler: self.operationEventHandler(for: handler)
    )
    .returnValue
  }

  /// Creates an ``OperationTask`` that performs a mutation.
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
  ///   - handler: A ``MutationEventHandler`` to subscribe to events from the mutation run.
  ///   (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func mutate(
    using context: OperationContext? = nil,
    handler: MutationEventHandler<State> = MutationEventHandler()
  ) async throws(State.Failure) -> State.Value {
    try await self.mutate(with: (), using: context, handler: handler)
  }

  /// Creates an ``OperationTask`` that performs a mutation with no arguments.
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
  /// > Warning: Calling this method without previously performing a mutation run attempt will
  /// > result in a crash.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` used by the underlying ``OperationTask``.
  ///   - handler: A ``MutationEventHandler`` to subscribe to events from the mutation run.
  ///   (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func retryLatest(
    using context: OperationContext? = nil,
    handler: MutationEventHandler<State> = MutationEventHandler()
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
  /// > Warning: Running the task returned by this method without previously performing a mutation
  /// > run attempt will result in a crash.
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
    with handler: MutationEventHandler<State>
  ) -> OperationSubscription {
    self.subscribe(with: self.operationEventHandler(for: handler))
  }
}

// MARK: - Event Handler

extension OperationStore where State: _MutationStateProtocol {
  private func operationEventHandler(
    for handler: MutationEventHandler<State>
  ) -> OperationEventHandler<State> {
    OperationEventHandler(
      onStateChanged: handler.onStateChanged,
      onRunStarted: {
        guard let args = $0.mutationArgs(as: State.Arguments.self) else { return }
        handler.onMutatingStarted?(args, $0)
      },
      onRunEnded: {
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
