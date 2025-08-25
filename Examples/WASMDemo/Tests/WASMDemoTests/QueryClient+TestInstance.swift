import Operation

extension OperationClient {
  static func testInstance() -> OperationClient {
    OperationClient(storeCreator: .defaultTesting)
  }
}
