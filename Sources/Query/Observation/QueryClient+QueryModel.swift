#if observation
  import SwiftNavigation

  #if canImport(SwiftUI)
    import SwiftUI
  #endif

  // MARK: - Model Inits

  @MainActor
  extension QueryClient {
    public func model<Query: QueryRequest>(
      for query: Query,
      initialState: Query.State,
      uiTransaction: UITransaction = UITransaction()
    ) -> QueryModel<Query.State> where Query.Value == Query.State.QueryValue {
      QueryModel(
        store: self.store(for: query, initialState: initialState),
        uiTransaction: uiTransaction
      )
    }

    public func model<Query: QueryRequest>(
      for query: Query,
      uiTransaction: UITransaction = UITransaction()
    ) -> QueryModel<Query.State> where Query.State == QueryState<Query.Value?, Query.Value> {
      QueryModel(store: self.store(for: query), uiTransaction: uiTransaction)
    }

    public func model<Query: QueryRequest>(
      for query: DefaultQuery<Query>,
      uiTransaction: UITransaction = UITransaction()
    ) -> QueryModel<DefaultQuery<Query>.State>
    where DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value> {
      QueryModel(store: self.store(for: query), uiTransaction: uiTransaction)
    }

    public func model<Query: InfiniteQueryRequest>(
      for query: Query,
      uiTransaction: UITransaction = UITransaction()
    ) -> QueryModel<Query.State> {
      QueryModel(store: self.store(for: query), uiTransaction: uiTransaction)
    }

    public func model<Query: InfiniteQueryRequest>(
      for query: DefaultInfiniteQuery<Query>,
      uiTransaction: UITransaction = UITransaction()
    ) -> QueryModel<DefaultInfiniteQuery<Query>.State> {
      QueryModel(store: self.store(for: query), uiTransaction: uiTransaction)
    }

    public func model<Mutation: MutationRequest>(
      for mutation: Mutation,
      uiTransaction: UITransaction = UITransaction()
    ) -> QueryModel<Mutation.State> {
      QueryModel(store: self.store(for: mutation), uiTransaction: uiTransaction)
    }
  }

  // MARK: - SwiftUI

  #if canImport(SwiftUI)
    @MainActor
    extension QueryClient {
      public func model<Query: QueryRequest>(
        for query: Query,
        initialState: Query.State,
        animation: Animation?
      ) -> QueryModel<Query.State> where Query.Value == Query.State.QueryValue {
        QueryModel(
          store: self.store(for: query, initialState: initialState),
          animation: animation
        )
      }

      public func model<Query: QueryRequest>(
        for query: Query,
        animation: Animation?
      ) -> QueryModel<Query.State>
      where Query.State == QueryState<Query.Value?, Query.Value> {
        QueryModel(store: self.store(for: query), animation: animation)
      }

      public func model<Query: QueryRequest>(
        for query: DefaultQuery<Query>,
        animation: Animation?
      ) -> QueryModel<DefaultQuery<Query>.State>
      where DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value> {
        QueryModel(store: self.store(for: query), animation: animation)
      }

      public func model<Query: InfiniteQueryRequest>(
        for query: Query,
        animation: Animation?
      ) -> QueryModel<Query.State> {
        QueryModel(store: self.store(for: query), animation: animation)
      }

      public func model<Query: InfiniteQueryRequest>(
        for query: DefaultInfiniteQuery<Query>,
        animation: Animation?
      ) -> QueryModel<DefaultInfiniteQuery<Query>.State> {
        QueryModel(store: self.store(for: query), animation: animation)
      }

      public func model<Mutation: MutationRequest>(
        for mutation: Mutation,
        animation: Animation?
      ) -> QueryModel<Mutation.State> {
        QueryModel(store: self.store(for: mutation), animation: animation)
      }
    }

    @MainActor
    extension QueryClient {
      public func model<Query: QueryRequest>(
        for query: Query,
        initialState: Query.State,
        transaction: Transaction
      ) -> QueryModel<Query.State> where Query.Value == Query.State.QueryValue {
        QueryModel(
          store: self.store(for: query, initialState: initialState),
          transaction: transaction
        )
      }

      public func model<Query: QueryRequest>(
        for query: Query,
        transaction: Transaction
      ) -> QueryModel<Query.State>
      where Query.State == QueryState<Query.Value?, Query.Value> {
        QueryModel(store: self.store(for: query), transaction: transaction)
      }

      public func model<Query: QueryRequest>(
        for query: DefaultQuery<Query>,
        transaction: Transaction
      ) -> QueryModel<DefaultQuery<Query>.State>
      where DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value> {
        QueryModel(store: self.store(for: query), transaction: transaction)
      }

      public func model<Query: InfiniteQueryRequest>(
        for query: Query,
        transaction: Transaction
      ) -> QueryModel<Query.State> {
        QueryModel(store: self.store(for: query), transaction: transaction)
      }

      public func model<Query: InfiniteQueryRequest>(
        for query: DefaultInfiniteQuery<Query>,
        transaction: Transaction
      ) -> QueryModel<DefaultInfiniteQuery<Query>.State> {
        QueryModel(store: self.store(for: query), transaction: transaction)
      }

      public func model<Mutation: MutationRequest>(
        for mutation: Mutation,
        transaction: Transaction
      ) -> QueryModel<Mutation.State> {
        QueryModel(store: self.store(for: mutation), transaction: transaction)
      }
    }
  #endif
#endif
