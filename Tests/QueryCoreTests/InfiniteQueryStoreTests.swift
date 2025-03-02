//import CustomDump
//import QueryCore
//import Testing

//@Suite("InfiniteQueryStore tests")
//struct InfiniteQueryStoreTests {
//  private let client = QueryClient()

//  @Test("Casts To InfiniteQueryStore From QueryStoreOfInfinitePages")
//  func testCastsToInfiniteQueryStore() {
//    let store = QueryStoreFor<TestInfiniteQuery>
//      .detached(query: TestInfiniteQuery(initialPageId: 0, path: []), initialValue: [])
//    let infiniteStore = InfiniteQueryStore(store: store)
//    expectNoDifference(infiniteStore != nil, true)
//  }

//  @Test("Casts To InfiniteQueryStore From AnyQueryStore")
//  func testCastsToInfiniteQueryStoreFromAnyQueryStore() {
//    let store = AnyQueryStore.detached(
//      erasing: TestInfiniteQuery(initialPageId: 0, path: []),
//      initialValue: TestInfiniteQuery.Value()
//    )
//    let infiniteStore = InfiniteQueryStoreFor<TestInfiniteQuery>(casting: store)
//    expectNoDifference(infiniteStore != nil, true)
//  }

//  @Test(
//    "Does Not Cast To InfiniteQueryStore From QueryStoreOfInfinitePages When Underlying Query Is Not Infinite"
//  )
//  func testDoesNotCastsToInfiniteQueryStore() {
//    //let store = QueryStoreFor<FakeInfiniteQuery>
//    //  .detached(query: FakeInfiniteQuery().defaultValue([]), initialValue: [])
//    //let infiniteStore = InfiniteQueryStore(store: store)
//    //expectNoDifference(infiniteStore == nil, true)
//  }

//  @Test(
//    "Does Not Cast To InfiniteQueryStore From AnyQueryStore When Underlying Query Is Not Infinite"
//  )
//  func testDoesNotCastsToInfiniteQueryStoreFromAnyQueryStore() {
//    let store = AnyQueryStore.detached(
//      erasing: FakeInfiniteQuery().defaultValue([]),
//      initialValue: FakeInfiniteQuery.Value()
//    )
//    let infiniteStore = InfiniteQueryStoreFor<TestInfiniteQuery>(casting: store)
//    expectNoDifference(infiniteStore == nil, true)
//  }

//  @Test(
//    "Does Not Cast To InfiniteQueryStore From AnyQueryStore When Type Mismatch"
//  )
//  func testDoesNotCastsToInfiniteQueryStoreFromAnyQueryStoreWithTypeMismatch() {
//    let store = AnyQueryStore.detached(
//      erasing: TestIntInfiniteQuery(initialPageId: 0, path: []).defaultValue([]),
//      initialValue: TestIntInfiniteQuery.Value()
//    )
//    let infiniteStore = InfiniteQueryStoreFor<TestInfiniteQuery>(casting: store)
//    expectNoDifference(infiniteStore == nil, true)
//  }
//}
