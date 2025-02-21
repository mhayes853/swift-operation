import CustomDump
import QueryCore
import Testing

@Suite("QueryStore tests")
struct QueryStoreTests {
  private let client = QueryClient()

  @Test("Store Has Default Value Initially")
  func hasDefaultValue() {
    let defaultValue = TestQuery.value + 1
    let store = self.client.store(for: TestQuery().defaultValue(defaultValue))
    expectNoDifference(store.value, defaultValue)
  }

  @Test("Store Has Nil Value Initially")
  func hasNilValue() {
    let store = self.client.store(for: TestQuery())
    expectNoDifference(store.value, nil)
  }

  //@Test("")
}

private struct TestQuery: QueryProtocol {
  static let value = 1

  typealias Value = Int

  func fetch(in context: QueryCore.QueryContext) async throws -> Value {
    Self.value
  }
}
