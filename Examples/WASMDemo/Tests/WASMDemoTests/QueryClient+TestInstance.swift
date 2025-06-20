import Query

extension QueryClient {
  static func testInstance() -> QueryClient {
    QueryClient(storeCreator: .defaultTesting)
  }
}