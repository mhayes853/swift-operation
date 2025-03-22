// MARK: - Typealiases

public typealias MutationStoreFor<
  Mutation: MutationRequest
> = MutationStore<Mutation.Arguments, Mutation.Value>

// MARK: - MutationStore

@dynamicMemberLookup
public final class MutationStore<Arguments: Sendable, Value: Sendable>: Sendable {
  public let base: QueryStore<MutationState<Arguments, Value>>

  public init(store: QueryStore<MutationState<Arguments, Value>>) {
    self.base = store
  }
}

// MARK: - Detached

extension MutationStore {
  public static func detached<Mutation: MutationRequest>(
    mutation: Mutation,
    initialContext: QueryContext = QueryContext()
  ) -> MutationStoreFor<Mutation> where Arguments == Mutation.Arguments, Value == Mutation.Value {
    MutationStoreFor<Mutation>(
      store: .detached(
        query: mutation,
        initialState: MutationState(),
        initialContext: initialContext
      )
    )
  }
}

// MARK: - Path

extension MutationStore {
  public var path: QueryPath {
    self.base.path
  }
}

// MARK: - Context

extension MutationStore {
  public var context: QueryContext {
    get { self.base.context }
    set { self.base.context = newValue }
  }
}

// MARK: - State

extension MutationStore {
  public var state: MutationState<Arguments, Value> {
    self.base.state
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<MutationState<Arguments, Value>, NewValue>
  ) -> NewValue {
    self.state[keyPath: keyPath]
  }
}

// MARK: - Mutate

extension MutationStore {
  @discardableResult
  public func mutate(
    with arguments: Arguments,
    using configuration: QueryTaskConfiguration? = nil,
    handler: MutationEventHandler<Arguments, Value> = MutationEventHandler()
  ) async throws -> Value {
    try await self.base.fetch(
      using: self.taskConfiguration(with: arguments, using: configuration),
      handler: self.queryStoreHandler(for: handler)
    )
  }

  public func mutateTask(
    with arguments: Arguments,
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<Value> {
    self.base.fetchTask(using: self.taskConfiguration(with: arguments, using: configuration))
  }

  private func taskConfiguration(
    with arguments: Arguments,
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

extension MutationStore {
  public func retryLatest(
    using configuration: QueryTaskConfiguration? = nil,
    handler: MutationEventHandler<Arguments, Value> = MutationEventHandler()
  ) async throws -> Value {
    try await self.base.fetch(
      using: self.retryTaskConfiguration(using: configuration),
      handler: self.queryStoreHandler(for: handler)
    )
  }

  public func retryLatestTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<Value> {
    self.base.fetchTask(using: self.retryTaskConfiguration(using: configuration))
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

extension MutationStore {
  public var subscriberCount: Int {
    self.base.subscriberCount
  }

  public func subscribe(
    with handler: MutationEventHandler<Arguments, Value>
  ) async throws -> QuerySubscription {
    self.base.subscribe(with: self.queryStoreHandler(for: handler))
  }
}

// MARK: - Event Handler

extension MutationStore {
  private func queryStoreHandler(
    for handler: MutationEventHandler<Arguments, Value>
  ) -> QueryEventHandler<Value> {
    QueryEventHandler<Value>(
      onFetchingStarted: {
        guard let args = $0.mutationArgs(as: Arguments.self) else { return }
        handler.onMutatingStarted?(args, $0)
      },
      onFetchingEnded: {
        guard let args = $0.mutationArgs(as: Arguments.self) else { return }
        handler.onMutatingEnded?(args, $0)
      },
      onResultReceived: {
        guard let args = $1.mutationArgs(as: Arguments.self) else { return }
        handler.onMutationResultReceived?(args, $0, $1)
      }
    )
  }
}
