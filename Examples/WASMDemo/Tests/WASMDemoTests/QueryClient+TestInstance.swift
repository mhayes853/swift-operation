import Operation

extension QueryClient {
  static func testInstance() -> QueryClient {
    QueryClient(storeCreator: .defaultTesting)
  }
}
