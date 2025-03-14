// MARK: - Typealiases

public typealias MutationStoreFor<
  Mutation: MutationProtocol
> = MutationStore<Mutation.Arguments, Mutation.Value>

// MARK: - MutationStore

@dynamicMemberLookup
public final class MutationStore<Arguments: Sendable, Value: Sendable>: Sendable {
  public let base: QueryStore<MutationState<Arguments, Value>>

  public init(store: QueryStore<MutationState<Arguments, Value>>) {
    self.base = store
  }
}

// MARK: - Casting

extension MutationStore {
  public convenience init?(casting store: OpaqueQueryStore) {
    guard let store = QueryStore<MutationState<Arguments, Value>>(casting: store) else {
      return nil
    }
    self.init(store: store)
  }
}

// MARK: - Detached

extension MutationStore {
  public static func detached<Mutation: MutationProtocol>(
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
    taskName: String? = nil,
    with arguments: Arguments,
    handler: MutationEventHandler<Arguments, Value> = MutationEventHandler(),
    using context: QueryContext? = nil
  ) async throws -> Value {
    var context = context ?? self.context
    context.mutationValues = MutationContextValues(arguments: arguments)
    return try await self.base.fetch(
      taskName: taskName ?? self.mutateTaskName,
      handler: self.queryStoreHandler(for: handler),
      using: context
    )
  }

  public func mutateTask(
    name: String? = nil,
    with arguments: Arguments,
    using context: QueryContext? = nil
  ) -> QueryTask<Value> {
    var context = context ?? self.context
    context.mutationValues = MutationContextValues(arguments: arguments)
    return self.base.fetchTask(name: name ?? self.mutateTaskName, using: context)
  }

  private var mutateTaskName: String {
    "\(typeName(Self.self, genericsAbbreviated: false)) Mutate Task"
  }
}

// MARK: - Retry Latest

extension MutationStore {
  public func retryLatest(
    taskName: String? = nil,
    handler: MutationEventHandler<Arguments, Value> = MutationEventHandler(),
    using context: QueryContext? = nil
  ) async throws -> Value {
    try await self.base.fetch(
      taskName: taskName ?? self.retryLatestTaskName,
      handler: self.queryStoreHandler(for: handler),
      using: context
    )
  }

  public func retryLatestTask(
    name: String? = nil,
    using context: QueryContext? = nil
  ) -> QueryTask<Value> {
    self.base.fetchTask(name: name ?? self.retryLatestTaskName, using: context)
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
