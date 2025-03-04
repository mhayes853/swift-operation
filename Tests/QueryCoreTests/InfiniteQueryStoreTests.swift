import CustomDump
import Testing

@testable import QueryCore

@Suite("InfiniteQueryStore tests")
struct InfiniteQueryStoreTests {
  private let client = QueryClient()

  @Test("Casts To InfiniteQueryStore From AnyQueryStore")
  func testCastsToInfiniteQueryStoreFromAnyQueryStore() {
    let store = AnyQueryStore.detached(
      erasing: EmptyInfiniteQuery(initialPageId: 0, path: []),
      initialValue: EmptyInfiniteQuery.Value()
    )
    let infiniteStore = InfiniteQueryStoreFor<EmptyInfiniteQuery>(casting: store)
    expectNoDifference(infiniteStore != nil, true)
  }

  @Test("Casts To InfiniteQueryStore From AnyQueryStore With Modifier")
  func testCastsToInfiniteQueryStoreFromAnyQueryStoreWithModifier() {
    let store = AnyQueryStore.detached(
      erasing: EmptyInfiniteQuery(initialPageId: 0, path: [])
        .enableAutomaticFetching(when: .fetchManuallyCalled),
      initialValue: EmptyInfiniteQuery.Value()
    )
    let infiniteStore = InfiniteQueryStoreFor<EmptyInfiniteQuery>(casting: store)
    expectNoDifference(infiniteStore != nil, true)
  }

  @Test(
    "Does Not Cast To InfiniteQueryStore From AnyQueryStore When Underlying Query Is Not Infinite"
  )
  func testDoesNotCastsToInfiniteQueryStoreFromAnyQueryStore() {
    let store = AnyQueryStore.detached(
      erasing: FakeInfiniteQuery().defaultValue([]),
      initialValue: FakeInfiniteQuery.Value()
    )
    let infiniteStore = InfiniteQueryStoreFor<EmptyInfiniteQuery>(casting: store)
    expectNoDifference(infiniteStore == nil, true)
  }

  @Test(
    "Does Not Cast To InfiniteQueryStore From AnyQueryStore When Type Mismatch"
  )
  func testDoesNotCastsToInfiniteQueryStoreFromAnyQueryStoreWithTypeMismatch() {
    let store = AnyQueryStore.detached(
      erasing: EmptyIntInfiniteQuery(initialPageId: 0, path: []).defaultValue([]),
      initialValue: EmptyIntInfiniteQuery.Value()
    )
    let infiniteStore = InfiniteQueryStoreFor<EmptyInfiniteQuery>(casting: store)
    expectNoDifference(infiniteStore == nil, true)
  }

  @Test("Returns Empty Array When No Pages After Fetching All Pages")
  func emptyArrayWhenNoPagesAfterFetchingAllPages() async throws {
    let store = self.client.store(for: TestInfiniteQuery())
    let pages = try await store.fetchAllPages()
    expectNoDifference(pages, [])
    expectNoDifference(store.state.currentValue, [])
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Fetch Next Page, Returns Page Data First")
  func fetchNextPageReturnsPageDataFirst() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock { $0[0] = "blob" }
    let store = self.client.store(for: query)
    let page = try await store.fetchNextPage()
    expectNoDifference(page, InfiniteQueryPage(id: 0, value: "blob"))
    expectNoDifference(store.state.currentValue, [InfiniteQueryPage(id: 0, value: "blob")])
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Fetch Next Page Concurrently, Returns Same Page Data")
  func fetchNextPageConcurrentlyReturnsSamePageData() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock { $0[0] = "blob" }
    let store = self.client.store(for: query)
    async let p1 = store.fetchNextPage()
    async let p2 = store.fetchNextPage()
    let (page1, page2) = try await (p1, p2)
    expectNoDifference(page1, InfiniteQueryPage(id: 0, value: "blob"))
    expectNoDifference(page2, page1)
    expectNoDifference(store.state.currentValue, [InfiniteQueryPage(id: 0, value: "blob")])
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Fetch Next Page, Returns Page Data For Next Page After First")
  func fetchNextPageReturnsPageDataForNextPageAfterFirst() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock {
      $0[0] = "blob"
      $0[1] = "blob jr"
    }
    let store = self.client.store(for: query)
    try await store.fetchNextPage()
    let page = try await store.fetchNextPage()
    expectNoDifference(page, InfiniteQueryPage(id: 1, value: "blob jr"))
    expectNoDifference(
      store.state.currentValue,
      [InfiniteQueryPage(id: 0, value: "blob"), InfiniteQueryPage(id: 1, value: "blob jr")]
    )
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Fetch Previous Page, Returns Page Data First")
  func fetchPreviousPageReturnsPageDataFirst() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock { $0[0] = "blob" }
    let store = self.client.store(for: query)
    let page = try await store.fetchPreviousPage()
    expectNoDifference(page, InfiniteQueryPage(id: 0, value: "blob"))
    expectNoDifference(store.state.currentValue, [InfiniteQueryPage(id: 0, value: "blob")])
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Fetch Previous Page Concurrently, Returns Same Page Data")
  func fetchPreviousPageConcurrentlyReturnsSamePageData() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock { $0[0] = "blob" }
    let store = self.client.store(for: query)
    async let p1 = store.fetchPreviousPage()
    async let p2 = store.fetchPreviousPage()
    let (page1, page2) = try await (p1, p2)
    expectNoDifference(page1, InfiniteQueryPage(id: 0, value: "blob"))
    expectNoDifference(page2, page1)
    expectNoDifference(store.state.currentValue, [InfiniteQueryPage(id: 0, value: "blob")])
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Fetch Next And Previous Page Concurrently When No Pages Fetched, Returns Same Page Data")
  func fetchNextAndPreviousConcurrentlyInitially() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock { $0[0] = "blob" }
    let store = self.client.store(for: query)
    async let p1 = store.fetchNextPage()
    async let p2 = store.fetchPreviousPage()
    let (page1, page2) = try await (p1, p2)
    expectNoDifference(page1, InfiniteQueryPage(id: 0, value: "blob"))
    expectNoDifference(page2, page1)
    expectNoDifference(store.state.currentValue, [InfiniteQueryPage(id: 0, value: "blob")])
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Fetch Previous Page, Returns Page Data Before First")
  func fetchPreviousPageReturnsPageDataBeforeFirst() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock {
      $0[0] = "blob"
      $0[-1] = "blob jr"
    }
    let store = self.client.store(for: query)
    try await store.fetchPreviousPage()
    let page = try await store.fetchPreviousPage()
    expectNoDifference(page, InfiniteQueryPage(id: -1, value: "blob jr"))
    expectNoDifference(
      store.state.currentValue,
      [InfiniteQueryPage(id: -1, value: "blob jr"), InfiniteQueryPage(id: 0, value: "blob")]
    )
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Fetch Previous Page, No Previous Page, Returns Nil")
  func fetchPreviousPageReturnsNilWithNoPreviousPage() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock {
      $0[0] = "blob"
      $0[1] = "blob jr"
    }
    let store = self.client.store(for: query)
    try await store.fetchPreviousPage()
    let page = try await store.fetchPreviousPage()
    expectNoDifference(page, nil)
    expectNoDifference(store.state.currentValue, [InfiniteQueryPage(id: 0, value: "blob")])
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Fetch Next Page, No Next Page, Returns Nil")
  func fetchNextPageReturnsNilWithNoNextPage() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock {
      $0[0] = "blob"
      $0[-1] = "blob jr"
    }
    let store = self.client.store(for: query)
    try await store.fetchNextPage()
    let page = try await store.fetchNextPage()
    expectNoDifference(page, nil)
    expectNoDifference(store.state.currentValue, [InfiniteQueryPage(id: 0, value: "blob")])
    expectNoDifference(store.state.status.isSuccessful, true)
  }
}
