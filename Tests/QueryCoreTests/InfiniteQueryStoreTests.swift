import CustomDump
import QueryCore
import Testing

@Suite("InfiniteQueryStore tests")
struct InfiniteQueryStoreTests {
  private let client = QueryClient()

  @Test("Casts To InfiniteQueryStore From QueryStoreOfInfinitePages")
  func testCastsToInfiniteQueryStore() {
    let store = QueryStoreFor<TestInfiniteQuery>
      .detached(query: TestInfiniteQuery(initialPageId: 0, path: []), initialValue: [])
    let infiniteStore = InfiniteQueryStore(store: store)
    expectNoDifference(infiniteStore != nil, true)
  }

  @Test(
    "Does Not Cast To InfiniteQueryStore From QueryStoreOfInfinitePages When Underlying Query Is Not Infinite"
  )
  func testDoesNotCastsToInfiniteQueryStore() {
    let store = QueryStoreFor<FakeInfiniteQuery>
      .detached(query: FakeInfiniteQuery().defaultValue([]), initialValue: [])
    let infiniteStore = InfiniteQueryStore(store: store)
    expectNoDifference(infiniteStore == nil, true)
  }
}
