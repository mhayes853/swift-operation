// MARK: - Detached

extension QueryStore {
  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``QueryClient``. As such, accessing the
  /// ``QueryContext/queryClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - mutation: The ``MutationRequest``.
  ///   - initialContext: The default ``QueryContext``.
  /// - Returns: A store.
  public static func detached<Arguments, Value, Mutation: MutationRequest<Arguments, Value>>(
    mutation: Mutation,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStore<MutationState<Arguments, Value>> where State == MutationState<Arguments, Value> {
    .detached(
      query: mutation,
      initialState: MutationState(),
      initialContext: initialContext
    )
  }
  
  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``QueryClient``. As such, accessing the
  /// ``QueryContext/queryClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - mutation: The ``MutationRequest``.
  ///   - initialValue: The initial value.
  ///   - initialContext: The default ``QueryContext``.
  /// - Returns: A store.
  public static func detached<Arguments, Value, Mutation: MutationRequest<Arguments, Value>>(
    mutation: Mutation,
    initialValue: Value?,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStore<MutationState<Arguments, Value>> where State == MutationState<Arguments, Value> {
    .detached(
      query: mutation,
      initialState: MutationState(initialValue: initialValue),
      initialContext: initialContext
    )
  }
  
  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``QueryClient``. As such, accessing the
  /// ``QueryContext/queryClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - mutation: The ``MutationRequest``.
  ///   - initialState: The initial state.
  ///   - initialContext: The default ``QueryContext``.
  /// - Returns: A store.
  public static func detached<Arguments, Value, Mutation: MutationRequest<Arguments, Value>>(
    mutation: Mutation,
    initialState: State,
    initialContext: QueryContext = QueryContext()
  ) -> QueryStore<MutationState<Arguments, Value>> where State == MutationState<Arguments, Value> {
    .detached(
      query: mutation,
      initialState: initialState,
      initialContext: initialContext
    )
  }
}

// MARK: - Mutate

extension QueryStore where State: _MutationStateProtocol {
  /// Performs a mutation.
  ///
  /// - Parameters:
  ///   - arguments: The set of arguments to mutate with.
  ///   - configuration: The ``QueryTaskConfiguration`` used by the underlying ``QueryTask``.
  ///   - handler: A ``QueryEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func mutate(
    with arguments: State.Arguments,
    using configuration: QueryTaskConfiguration? = nil,
    handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
  ) async throws -> State.Value {
    try await self.fetch(
      using: self.taskConfiguration(with: arguments, using: configuration),
      handler: self.queryStoreHandler(for: handler)
    )
  }
  
  /// Creates a ``QueryTask`` that performs a mutation.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``QueryTask/runIfNeeded()`` to fetch the data.
  ///
  /// - Parameters:
  ///   - arguments: The set of arguments to mutate with.
  ///   - configuration: The ``QueryTaskConfiguration`` for the task.
  /// - Returns: A task to perform the mutation.
  public func mutateTask(
    with arguments: State.Arguments,
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<State.Value> {
    self.fetchTask(using: self.taskConfiguration(with: arguments, using: configuration))
  }

  private func taskConfiguration(
    with arguments: State.Arguments,
    using base: QueryTaskConfiguration?
  ) -> QueryTaskConfiguration {
    var config = base ?? QueryTaskConfiguration(context: self.context)
    config.context.mutationValues = MutationContextValues(arguments: arguments)
    config.name = config.name ?? self.mutateTaskName
    return config
  }

  private var mutateTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Mutate Task"
  }
}

extension QueryStore where State: _MutationStateProtocol, State.Arguments == Void {
  /// Performs a mutation with no arguments.
  ///
  /// - Parameters:
  ///   - configuration: The ``QueryTaskConfiguration`` used by the underlying ``QueryTask``.
  ///   - handler: A ``MutationEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func mutate(
    using configuration: QueryTaskConfiguration? = nil,
    handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
  ) async throws -> State.Value {
    try await self.mutate(with: (), using: configuration, handler: handler)
  }

  /// Creates a ``QueryTask`` that performs a mutation with no arguments.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``QueryTask/runIfNeeded()`` to fetch the data.
  ///
  /// - Parameters:
  ///   - configuration: The ``QueryTaskConfiguration`` for the task.
  /// - Returns: A task to perform the mutation.
  public func mutateTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<State.Value> {
    self.mutateTask(with: (), using: configuration)
  }
}

// MARK: - Retry Latest

extension QueryStore where State: _MutationStateProtocol {
  /// Retries the mutation with the most recently used set of arguments.
  ///
  /// > Important: Calling this method without previously having called ``mutate(using:handler:)``
  /// > will result in a purple runtime warning in Xcode, and a test failure for current running
  /// > test. Additionally, the mutation will also throw an error.
  ///
  /// - Parameters:
  ///   - configuration: The ``QueryTaskConfiguration`` used by the underlying ``QueryTask``.
  ///   - handler: A ``MutationEventHandler`` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func retryLatest(
    using configuration: QueryTaskConfiguration? = nil,
    handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
  ) async throws -> State.Value {
    try await self.fetch(
      using: self.retryTaskConfiguration(using: configuration),
      handler: self.queryStoreHandler(for: handler)
    )
  }

  /// Creates a ``QueryTask`` that retries the mutation with the most recently used set of
  /// arguments.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// ``QueryTask/runIfNeeded()`` to fetch the data.
  ///
  /// > Important: Calling this method without previously having called ``mutate(using:handler:)``
  /// > will result in a purple runtime warning in Xcode, and a test failure for current running
  /// > test. Additionally, the mutation will also throw an error.
  ///
  /// - Parameters:
  ///   - configuration: The ``QueryTaskConfiguration`` for the task.
  /// - Returns: A task to retry the most recently used arguments on the mutation.
  public func retryLatestTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<State.Value> {
    self.fetchTask(using: self.retryTaskConfiguration(using: configuration))
  }

  private func retryTaskConfiguration(
    using base: QueryTaskConfiguration?
  ) -> QueryTaskConfiguration {
    var config = base ?? QueryTaskConfiguration(context: self.context)
    config.name = config.name ?? self.retryLatestTaskName
    return config
  }

  private var retryLatestTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Retry Latest Task"
  }
}

// MARK: - Subscribe

extension QueryStore where State: _MutationStateProtocol {
  /// Subscribes to events from this store using a ``MutationEventHandler``.
  ///
  /// - Parameter handler: The event handler.
  /// - Returns: A ``QuerySubscription``.
  public func subscribe(
    with handler: MutationEventHandler<State.Arguments, State.Value>
  ) async throws -> QuerySubscription {
    self.subscribe(with: self.queryStoreHandler(for: handler))
  }
}

// MARK: - Event Handler

extension QueryStore where State: _MutationStateProtocol {
  private func queryStoreHandler(
    for handler: MutationEventHandler<State.Arguments, State.Value>
  ) -> QueryEventHandler<State> {
    QueryEventHandler(
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
        handler.onMutationResultReceived?(args, $0, $1)
      }
    )
  }
}
