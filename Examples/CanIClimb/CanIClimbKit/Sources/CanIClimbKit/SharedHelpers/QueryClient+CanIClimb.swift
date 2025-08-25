import Operation

// MARK: - Shared Instance

extension QueryClient {
  public static let canIClimb = QueryClient(storeCreator: .canIClimb)
}

// MARK: - CanIClimbStoreCreator

extension QueryClient {
  public struct CanIClimbStoreCreator: StoreCreator {
    let base: any StoreCreator

    public func store<Query>(
      for query: Query,
      in context: QueryContext,
      with initialState: Query.State
    ) -> QueryStore<Query.State> where Query: QueryRequest {
      self.base.store(for: query.analyzed().previewDelay(), in: context, with: initialState)
    }
  }
}

extension QueryClient.StoreCreator where Self == QueryClient.CanIClimbStoreCreator {
  public static var canIClimb: Self {
    QueryClient.CanIClimbStoreCreator(base: .default())
  }

  public static func canIClimb(_ base: any QueryClient.StoreCreator) -> Self {
    QueryClient.CanIClimbStoreCreator(base: base)
  }
}
