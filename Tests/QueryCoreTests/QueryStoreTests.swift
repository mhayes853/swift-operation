import CustomDump
import QueryCore
import Testing

@Suite("QueryStore tests")
struct QueryStoreTests {
  @Test("Store Has Default Value Initially")
  func hasDefaultValue() {
    let client = QueryClient()
    let defaultValue = TestQuery.value + 1
    let store = client.store(for: TestQuery().withDefault(defaultValue))
    expectNoDifference(store.value, defaultValue)
  }

  @Test("Store Has Nil Value Initially")
  func hasNilValue() {
    let client = QueryClient()
    let store = client.store(for: TestQuery())
    expectNoDifference(store.value, nil)
  }
}

private struct TestQuery: QueryProtocol {
  static let value = 1

  typealias Value = Int

  func fetch(in context: QueryCore.QueryContext) async throws -> Value {
    Self.value
  }
}
