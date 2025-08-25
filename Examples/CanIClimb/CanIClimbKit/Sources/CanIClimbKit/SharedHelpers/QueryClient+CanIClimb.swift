import Operation

// MARK: - Shared Instance

extension OperationClient {
  public static let canIClimb = OperationClient(storeCreator: .canIClimb)
}

// MARK: - CanIClimbStoreCreator

extension OperationClient {
  public struct CanIClimbStoreCreator: StoreCreator {
    let base: any StoreCreator

    public func store<Query>(
      for query: Query,
      in context: OperationContext,
      with initialState: Query.State
    ) -> OperationStore<Query.State> where Query: QueryRequest {
      self.base.store(for: query.analyzed().previewDelay(), in: context, with: initialState)
    }
  }
}

extension OperationClient.StoreCreator where Self == OperationClient.CanIClimbStoreCreator {
  public static var canIClimb: Self {
    OperationClient.CanIClimbStoreCreator(base: .default())
  }

  public static func canIClimb(_ base: any OperationClient.StoreCreator) -> Self {
    OperationClient.CanIClimbStoreCreator(base: base)
  }
}
