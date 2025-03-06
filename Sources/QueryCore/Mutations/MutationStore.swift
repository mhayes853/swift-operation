// MARK: - Typealiases

public typealias MutationStoreFor<
  Mutation: MutationProtocol
> = MutationStore<Mutation.Value, Mutation.Arguments>

// MARK: - MutationStore

public final class MutationStore<Value: Sendable, Arguments: Sendable>: Sendable {
  private let base: QueryStore<MutationState<Value>>

  public init(store: QueryStore<MutationState<Value>>) {
    self.base = store
  }
}

// MARK: - Casting

extension MutationStore {
  public convenience init?(casting store: AnyQueryStore) {
    guard let store = QueryStore<MutationState<Value>>(casting: store) else {
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
  ) -> MutationStoreFor<Mutation> {
    MutationStoreFor<Mutation>(store: .detached(mutation: mutation, initialContext: initialContext))
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
  public var state: MutationState<Value> {
    self.base.state
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<MutationState<Value>, NewValue>
  ) -> NewValue {
    self.state[keyPath: keyPath]
  }
}

// MARK: - Mutate

extension MutationStore {
  public func mutate(
    with arguments: Arguments,
    handler: MutationEventHandler<Arguments, Value> = MutationEventHandler(),
    using context: QueryContext? = nil
  ) async throws -> Value {
    fatalError()
  }
}

// MARK: - Subscribe

extension MutationStore {
  public func subscribe(
    with handler: MutationEventHandler<Arguments, Value>
  ) async throws -> QuerySubscription {
    fatalError()
  }
}
