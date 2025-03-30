// MARK: - Detached

extension QueryStore {
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
}

// MARK: - Mutate

extension QueryStore where State: _MutationStateProtocol {
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

// MARK: - Retry Latest

extension QueryStore where State: _MutationStateProtocol {
  public func retryLatest(
    using configuration: QueryTaskConfiguration? = nil,
    handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
  ) async throws -> State.Value {
    try await self.fetch(
      using: self.retryTaskConfiguration(using: configuration),
      handler: self.queryStoreHandler(for: handler)
    )
  }

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
