#if canImport(SwiftUI)
  import SwiftUI
  import Dependencies

  // MARK: - Store Initializer

  extension SharedQuery {
    public init(store: QueryStore<State>, animation: Animation) {
      let shared = Shared(
        wrappedValue: QueryStateKeyValue(store: store),
        QueryStateKey(store: store, scheduler: AnimationStateScheduler(animation: animation))
      )
      self.init(value: shared)
    }
  }

  // MARK: - Query State Initializer

  extension SharedQuery {
    public init<Query: QueryRequest>(
      _ query: Query,
      initialState: Query.State,
      client: QueryClient? = nil,
      animation: Animation
    ) where State == Query.State {
      @Dependency(\.defaultQueryClient) var queryClient
      self.init(
        store: (client ?? queryClient).store(for: query, initialState: initialState),
        animation: animation
      )
    }
  }

  // MARK: - Query Initializers

  extension SharedQuery {
    public init<Value: Sendable, Query: QueryRequest<Value, QueryState<Value?, Value>>>(
      wrappedValue: Query.State.StateValue = nil,
      _ query: Query,
      client: QueryClient? = nil,
      animation: Animation
    ) where State == Query.State {
      self.init(
        query,
        initialState: QueryState(initialValue: wrappedValue),
        client: client,
        animation: animation
      )
    }

    public init<Query: QueryRequest>(
      _ query: DefaultQuery<Query>,
      client: QueryClient? = nil,
      animation: Animation
    ) where State == DefaultQuery<Query>.State {
      self.init(
        query,
        initialState: QueryState(initialValue: query.defaultValue),
        client: client,
        animation: animation
      )
    }
  }

  // MARK: - InfiniteQuery Initializers

  extension SharedQuery {
    public init<Query: InfiniteQueryRequest>(
      wrappedValue: Query.State.StateValue = [],
      _ query: Query,
      client: QueryClient? = nil,
      animation: Animation
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
      self.init(
        query,
        initialState: InfiniteQueryState(
          initialValue: wrappedValue,
          initialPageId: query.initialPageId
        ),
        client: client,
        animation: animation
      )
    }

    public init<Query: InfiniteQueryRequest>(
      _ query: DefaultInfiniteQuery<Query>,
      client: QueryClient? = nil,
      animation: Animation
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
      self.init(
        query,
        initialState: InfiniteQueryState(
          initialValue: query.defaultValue,
          initialPageId: query.initialPageId
        ),
        client: client,
        animation: animation
      )
    }
  }

  // MARK: - Mutation Initializer

  extension SharedQuery {
    public init<
      Arguments: Sendable,
      Value: Sendable,
      Mutation: MutationRequest<Arguments, Value>
    >(_ mutation: Mutation, client: QueryClient? = nil, animation: Animation)
    where State == MutationState<Arguments, Value> {
      self.init(mutation, initialState: MutationState(), client: client, animation: animation)
    }
  }

  // MARK: - DynamicProperty

  extension SharedQuery: DynamicProperty {
    public func update() {
      self.$value.update()
    }
  }
#endif
