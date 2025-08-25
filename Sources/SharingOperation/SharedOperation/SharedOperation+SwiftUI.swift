#if canImport(SwiftUI)
  import SwiftUI
  import Dependencies

  // MARK: - Store Initializer

  extension SharedOperation {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - store: The `OperationStore` to subscribe to.
    ///   - scheduler: The `Animation` to use for state updates.
    public init(store: OperationStore<State>, animation: Animation) {
      self.init(store: store, scheduler: .animation(animation))
    }
  }

  // MARK: - Operation State Initializer

  extension SharedOperation {
    /// Creates a shared operation.
    ///
    /// - Parameters:
    ///   - operation: The `OperationRequest`.
    ///   - initialState: The initial state.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - scheduler: The ``SharedOperationStateScheduler`` to schedule state updates on.
    public init<Operation: OperationRequest & Sendable>(
      _ operation: Operation,
      initialState: Operation.State,
      client: OperationClient? = nil,
      animation: Animation
    ) where State == Operation.State {
      self.init(
        operation,
        initialState: initialState,
        client: client,
        scheduler: .animation(animation)
      )
    }
  }

  // MARK: - Query State Initializer

  extension SharedOperation {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `QueryRequest`.
    ///   - initialState: The initial state.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `Animation` to use for state updates.
    public init<Query: QueryRequest>(
      _ query: Query,
      initialState: Query.State,
      client: OperationClient? = nil,
      animation: Animation
    ) where State == Query.State {
      self.init(
        query,
        initialState: initialState,
        client: client,
        scheduler: .animation(animation)
      )
    }
  }

  // MARK: - Query Initializers

  extension SharedOperation {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `QueryRequest`.
    ///   - wrappedValue: The initial value.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `Animation` to use for state updates.
    public init<Value: Sendable, Query: QueryRequest<Value, QueryState<Value?, Value>>>(
      wrappedValue: Query.State.StateValue = nil,
      _ query: Query,
      client: OperationClient? = nil,
      animation: Animation
    ) where State == Query.State {
      self.init(
        wrappedValue: wrappedValue,
        query,
        client: client,
        scheduler: .animation(animation)
      )
    }

    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `QueryRequest`.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `Animation` to use for state updates.
    public init<Query: QueryRequest>(
      _ query: DefaultQuery<Query>,
      client: OperationClient? = nil,
      animation: Animation
    ) where State == DefaultQuery<Query>.State {
      self.init(query, client: client, scheduler: .animation(animation))
    }
  }

  // MARK: - InfiniteQuery Initializers

  extension SharedOperation {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `InfiniteQueryRequest`.
    ///   - wrappedValue: The initial value.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `Animation` to use for state updates.
    public init<Query: InfiniteQueryRequest>(
      wrappedValue: Query.State.StateValue = [],
      _ query: Query,
      client: OperationClient? = nil,
      animation: Animation
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
      self.init(
        wrappedValue: wrappedValue,
        query,
        client: client,
        scheduler: .animation(animation)
      )
    }

    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `InfiniteQueryRequest`.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `Animation` to use for state updates.
    public init<Query: InfiniteQueryRequest>(
      _ query: DefaultInfiniteQuery<Query>,
      client: OperationClient? = nil,
      animation: Animation
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
      self.init(query, client: client, scheduler: .animation(animation))
    }
  }

  // MARK: - Mutation Initializer

  extension SharedOperation {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - mutation: The `MutationRequest`.
    ///   - wrappedValue: The initial value.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `Animation` to use for state updates.
    public init<
      Arguments: Sendable,
      Value: Sendable,
      Mutation: MutationRequest<Arguments, Value>
    >(
      wrappedValue: Value?,
      _ mutation: Mutation,
      client: OperationClient? = nil,
      animation: Animation
    ) where State == MutationState<Arguments, Value> {
      self.init(
        mutation,
        initialState: MutationState(initialValue: wrappedValue),
        client: client,
        scheduler: .animation(animation)
      )
    }

    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - mutation: The `MutationRequest`.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `Animation` to use for state updates.
    public init<
      Arguments: Sendable,
      Value: Sendable,
      Mutation: MutationRequest<Arguments, Value>
    >(
      _ mutation: Mutation,
      client: OperationClient? = nil,
      animation: Animation
    ) where State == MutationState<Arguments, Value> {
      self.init(mutation, client: client, scheduler: .animation(animation))
    }
  }

  // MARK: - DynamicProperty

  extension SharedOperation: DynamicProperty {
    public func update() {
      self.$value.update()
    }
  }
#endif
