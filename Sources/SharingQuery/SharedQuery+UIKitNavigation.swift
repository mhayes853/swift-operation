#if UIKitNavigation && canImport(UIKitNavigation)
  import UIKitNavigation
  import Dependencies

  // MARK: - Store Initializer

  extension SharedQuery {
    public init(store: QueryStore<State>, animation: UIKitAnimation) {
      self.init(store: store, scheduler: .transaction(UITransaction(animation: animation)))
    }
  }

  // MARK: - Query State Initializer

  extension SharedQuery {
    public init<Query: QueryRequest>(
      _ query: Query,
      initialState: Query.State,
      client: QueryClient? = nil,
      animation: UIKitAnimation
    ) where State == Query.State {
      self.init(
        query,
        initialState: initialState,
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
    }
  }

  // MARK: - Query Initializers

  extension SharedQuery {
    public init<Value: Sendable, Query: QueryRequest<Value, QueryState<Value?, Value>>>(
      wrappedValue: Query.State.StateValue = nil,
      _ query: Query,
      client: QueryClient? = nil,
      animation: UIKitAnimation
    ) where State == Query.State {
      self.init(
        wrappedValue: wrappedValue,
        query,
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
    }

    public init<Query: QueryRequest>(
      _ query: DefaultQuery<Query>,
      client: QueryClient? = nil,
      animation: UIKitAnimation
    ) where State == DefaultQuery<Query>.State {
      self.init(query, client: client, scheduler: .transaction(UITransaction(animation: animation)))
    }
  }

  // MARK: - InfiniteQuery Initializers

  extension SharedQuery {
    public init<Query: InfiniteQueryRequest>(
      wrappedValue: Query.State.StateValue = [],
      _ query: Query,
      client: QueryClient? = nil,
      animation: UIKitAnimation
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
      self.init(
        wrappedValue: wrappedValue,
        query,
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
    }

    public init<Query: InfiniteQueryRequest>(
      _ query: DefaultInfiniteQuery<Query>,
      client: QueryClient? = nil,
      animation: UIKitAnimation
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
      self.init(query, client: client, scheduler: .transaction(UITransaction(animation: animation)))
    }
  }

  // MARK: - Mutation Initializer

  extension SharedQuery {
    public init<
      Arguments: Sendable,
      Value: Sendable,
      Mutation: MutationRequest<Arguments, Value>
    >(
      _ mutation: Mutation,
      client: QueryClient? = nil,
      animation: UIKitAnimation
    ) where State == MutationState<Arguments, Value> {
      self.init(
        mutation,
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
    }
  }
#endif
