import Operation

// MARK: - Shared Instance

extension OperationClient {
  public static let canIClimb = OperationClient(storeCreator: .canIClimb)
}

// MARK: - CanIClimbStoreCreator

extension OperationClient {
  public struct CanIClimbStoreCreator: StoreCreator, Sendable {
    let base: any StoreCreator & Sendable

    public func store<Operation: StatefulOperationRequest & Sendable>(
      for query: Operation,
      in context: OperationContext,
      with initialState: Operation.State
    ) -> OperationStore<Operation.State> {
      self.base.store(for: query.analyzed().previewDelay(), in: context, with: initialState)
    }
  }
}

extension OperationClient.StoreCreator where Self == OperationClient.CanIClimbStoreCreator {
  public static var canIClimb: Self {
    OperationClient.CanIClimbStoreCreator(base: .default())
  }

  public static func canIClimb(_ base: any OperationClient.StoreCreator & Sendable) -> Self {
    OperationClient.CanIClimbStoreCreator(base: base)
  }
}
