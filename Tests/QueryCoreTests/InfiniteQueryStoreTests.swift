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
      initialValue: []
    )
    let infiniteStore = InfiniteQueryStoreFor<EmptyInfiniteQuery>(casting: store)
    expectNoDifference(infiniteStore != nil, true)
  }

  @Test("Casts To InfiniteQueryStore From AnyQueryStore With Modifier")
  func testCastsToInfiniteQueryStoreFromAnyQueryStoreWithModifier() {
    let store = AnyQueryStore.detached(
      erasing: EmptyInfiniteQuery(initialPageId: 0, path: [])
        .enableAutomaticFetching(when: .always(false)),
      initialValue: []
    )
    let infiniteStore = InfiniteQueryStoreFor<EmptyInfiniteQuery>(casting: store)
    expectNoDifference(infiniteStore != nil, true)
  }

  @Test(
    "Does Not Cast To InfiniteQueryStore From AnyQueryStore When Underlying Query Is Not Infinite"
  )
  func testDoesNotCastsToInfiniteQueryStoreFromAnyQueryStore() {
    let store = AnyQueryStore.detached(
      erasing: FakeInfiniteQuery().defaultValue([])
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
      initialValue: []
    )
    let infiniteStore = InfiniteQueryStoreFor<EmptyInfiniteQuery>(casting: store)
    expectNoDifference(infiniteStore == nil, true)
  }

  @Test("Is Loading All Pages When Fetching All Pages")
  func isLoadingWhenFetchingAllPages() async throws {
    let query = WaitableInfiniteQuery()
    query.state.withLock { $0.values = [0: "a"] }

    let store = self.client.store(for: query)
    try await store.fetchNextPage()

    query.state.withLock {
      $0.willWait = true
      $0.onLoading = {
        expectNoDifference(store.state.isLoading, true)
        expectNoDifference(store.state.isLoadingAllPages, true)
        expectNoDifference(store.state.isLoadingInitialPage, false)
        expectNoDifference(store.state.isLoadingNextPage, false)
        expectNoDifference(store.state.isLoadingPreviousPage, false)
      }
    }
    Task { try await store.fetchAllPages() }
    try await query.waitForLoading()
  }

  @Test("Returns Empty Array When No Pages After Fetching All Pages")
  func emptyArrayWhenNoPagesAfterFetchingAllPages() async throws {
    let store = self.client.store(for: TestInfiniteQuery())
    let pages = try await store.fetchAllPages()
    expectNoDifference(pages, [])
    expectNoDifference(store.state.currentValue, [])
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Has Next And Previous Page After Fetching All Pages When Empty")
  func hasNextAndPreviousPageAfterFetchingAllPagesWhenEmpty() async throws {
    let store = self.client.store(for: TestInfiniteQuery())
    try await store.fetchAllPages()
    expectNoDifference(store.hasNextPage, true)
    expectNoDifference(store.hasPreviousPage, true)
  }

  @Test("Fetch All Pages After Fetching Some, Returns Updated Values For Refetched Pages")
  func fetchAllPagesAfterFetchingSome() async throws {
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query)

    query.state.withLock { $0 = [0: "a", 1: "b"] }
    try await store.fetchNextPage()
    try await store.fetchNextPage()

    query.state.withLock { $0 = [0: "c", 1: "d", 2: "e"] }
    let pages = try await store.fetchAllPages()

    let expectedPages = InfiniteQueryPages<Int, String>(
      uniqueElements: [InfiniteQueryPage(id: 0, value: "c"), InfiniteQueryPage(id: 1, value: "d")]
    )
    expectNoDifference(pages, expectedPages)
    expectNoDifference(store.state.currentValue, expectedPages)
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Fetch All Pages After Fetching Some, Stops Refetching When No Next Page ID")
  func fetchAllPagesAfterFetchingSomeStopsWhenNoNextPageID() async throws {
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query)
    query.state.withLock { $0 = [0: "a", 1: "b"] }
    try await store.fetchNextPage()
    try await store.fetchNextPage()
    query.state.withLock { $0 = [0: "c"] }
    let pages = try await store.fetchAllPages()
    let expectedPages = InfiniteQueryPages<Int, String>(
      uniqueElements: [InfiniteQueryPage(id: 0, value: "c")]
    )
    expectNoDifference(pages, expectedPages)
    expectNoDifference(store.state.currentValue, expectedPages)
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Fetch All Pages After Fetching Some, Starts From Earliest Page")
  func fetchAllPagesAfterFetchingSomeStartsFromEarliestPage() async throws {
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query)

    query.state.withLock { $0 = [-1: "c", 0: "a", 1: "b"] }
    try await store.fetchNextPage()
    try await store.fetchNextPage()

    query.state.withLock { $0 = [-1: "d", 0: "e", 1: "f"] }
    try await store.fetchPreviousPage()
    let pages = try await store.fetchAllPages()

    let expectedPages = InfiniteQueryPages<Int, String>(
      uniqueElements: [
        InfiniteQueryPage(id: -1, value: "d"),
        InfiniteQueryPage(id: 0, value: "e"),
        InfiniteQueryPage(id: 1, value: "f")
      ]
    )
    expectNoDifference(pages, expectedPages)
    expectNoDifference(store.state.currentValue, expectedPages)
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

  @Test("Is Loading Initial And Next When Fetching Next Page")
  func isLoadingInitialAndNextWhenFetchingNextPage() async throws {
    let query = WaitableInfiniteQuery()
    query.state.withLock {
      $0.values = [0: "a"]
      $0.willWait = true
    }

    let store = self.client.store(for: query)
    query.state.withLock {
      $0.onLoading = {
        expectNoDifference(store.state.isLoading, true)
        expectNoDifference(store.state.isLoadingAllPages, false)
        expectNoDifference(store.state.isLoadingInitialPage, true)
        expectNoDifference(store.state.isLoadingNextPage, true)
        expectNoDifference(store.state.isLoadingPreviousPage, false)
      }
    }
    Task { try await store.fetchNextPage() }
    try await query.waitForLoading()
  }

  @Test("Is Loading Next When Fetching Next Page After Fetching Initial Page")
  func isLoadingNextWhenFetchingNextPageAfterFetchingInitialPage() async throws {
    let query = WaitableInfiniteQuery()
    query.state.withLock { $0.values = [0: "a", 1: "b"] }
    let store = self.client.store(for: query)
    try await store.fetchNextPage()

    query.state.withLock {
      $0.willWait = true
      $0.onLoading = {
        expectNoDifference(store.state.isLoading, true)
        expectNoDifference(store.state.isLoadingAllPages, false)
        expectNoDifference(store.state.isLoadingInitialPage, false)
        expectNoDifference(store.state.isLoadingNextPage, true)
        expectNoDifference(store.state.isLoadingPreviousPage, false)
      }
    }

    Task { try await store.fetchNextPage() }
    try await query.waitForLoading()
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
    query.state.withLock { $0 = [0: "blob", 1: "blob jr"] }
    let store = self.client.store(for: query)

    try await store.fetchNextPage()
    expectNoDifference(store.hasNextPage, true)
    expectNoDifference(store.hasPreviousPage, false)

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
    query.state.withLock { $0 = [0: "blob"] }
    let store = self.client.store(for: query)
    let page = try await store.fetchPreviousPage()
    expectNoDifference(page, InfiniteQueryPage(id: 0, value: "blob"))
    expectNoDifference(store.state.currentValue, [InfiniteQueryPage(id: 0, value: "blob")])
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Is Loading Initial And Previous When Fetching Previous Page")
  func isLoadingInitialAndPreviousWhenFetchingPreviousPage() async throws {
    let query = WaitableInfiniteQuery()
    query.state.withLock {
      $0.values = [0: "a"]
      $0.willWait = true
    }

    let store = self.client.store(for: query)
    query.state.withLock {
      $0.onLoading = {
        expectNoDifference(store.isLoading, true)
        expectNoDifference(store.isLoadingAllPages, false)
        expectNoDifference(store.isLoadingInitialPage, true)
        expectNoDifference(store.isLoadingNextPage, false)
        expectNoDifference(store.isLoadingPreviousPage, true)
      }
    }
    Task { try await store.fetchPreviousPage() }
    try await query.waitForLoading()
  }

  @Test("Is Loading Previous When Fetching Previous Page After Fetching Initial Page")
  func isLoadingPreviousWhenFetchingPreviousPageAfterFetchingInitialPage() async throws {
    let query = WaitableInfiniteQuery()
    query.state.withLock { $0.values = [0: "a", -1: "b"] }
    let store = self.client.store(for: query)
    try await store.fetchPreviousPage()

    query.state.withLock {
      $0.willWait = true
      $0.onLoading = {
        expectNoDifference(store.state.isLoading, true)
        expectNoDifference(store.state.isLoadingAllPages, false)
        expectNoDifference(store.state.isLoadingInitialPage, false)
        expectNoDifference(store.state.isLoadingNextPage, false)
        expectNoDifference(store.state.isLoadingPreviousPage, true)
      }
    }

    Task { try await store.fetchPreviousPage() }
    try await query.waitForLoading()
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
    let store = self.client.store(for: query)

    query.state.withLock { $0 = [0: "blob", -1: "blob jr"] }
    try await store.fetchPreviousPage()
    expectNoDifference(store.hasNextPage, false)
    expectNoDifference(store.hasPreviousPage, true)

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
    query.state.withLock { $0 = [0: "blob", 1: "blob jr"] }
    let store = self.client.store(for: query)
    try await store.fetchPreviousPage()
    let page = try await store.fetchPreviousPage()
    expectNoDifference(page, nil)
    expectNoDifference(store.currentValue, [InfiniteQueryPage(id: 0, value: "blob")])
    expectNoDifference(store.status.isSuccessful, true)
  }

  @Test("Fetch Previous Page, Detects When No Previous Page After Fetching Initial Page")
  func fetchPreviousPageReturnsNilWithNoPreviousPageAfterFetchingInitialPage() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock { $0 = [0: "blob"] }
    let store = self.client.store(for: query)
    try await store.fetchPreviousPage()
    expectNoDifference(store.hasPreviousPage, false)
  }

  @Test("Fetch Next Page, No Next Page, Returns Nil")
  func fetchNextPageReturnsNilWithNoNextPage() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock { $0 = [0: "blob", -1: "blob jr"] }
    let store = self.client.store(for: query)
    try await store.fetchNextPage()
    let page = try await store.fetchNextPage()
    expectNoDifference(page, nil)
    expectNoDifference(store.currentValue, [InfiniteQueryPage(id: 0, value: "blob")])
    expectNoDifference(store.status.isSuccessful, true)
  }

  @Test("Fetch Next Page, Detects Whe No Next Page After Fetching Initial Page")
  func fetchNextPageReturnsNilWithNoNextPageAfterFetchingInitialPage() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock { $0 = [0: "blob"] }
    let store = self.client.store(for: query)
    try await store.fetchNextPage()
    expectNoDifference(store.hasNextPage, false)
  }

  @Test("Fetch Next Page While Fetching All, Always Fetches Next Page After Fetching All")
  func fetchNextPageWhileFetchingAllAlwaysFetchesNextPageAfterFetchingAll() async throws {
    let query = WaitableInfiniteQuery()
    let store = self.client.store(for: query)

    query.state.withLock { $0.values = [0: "blob", 1: "blob jr", 2: "b", 3: "c"] }
    for _ in 0..<2 {
      try await store.fetchNextPage()
    }

    query.state.withLock {
      $0.values = [0: "a", 2: "b", 3: "c"]
      $0.nextPageIds = [0: 2]
      $0.willWait = true
    }
    let all = Task { try await store.fetchAllPages() }
    try await query.waitForLoading()
    let next = Task { try await store.fetchNextPage() }
    try await query.waitForLoading()
    let pages = try await all.value
    await query.advance()
    let page = try await next.value

    expectNoDifference(
      pages,
      [InfiniteQueryPage(id: 0, value: "a"), InfiniteQueryPage(id: 2, value: "b")]
    )
    expectNoDifference(page, InfiniteQueryPage(id: 3, value: "c"))
    expectNoDifference(
      store.state.currentValue,
      [
        InfiniteQueryPage(id: 0, value: "a"),
        InfiniteQueryPage(id: 2, value: "b"),
        InfiniteQueryPage(id: 3, value: "c")
      ]
    )
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Fetch Previous Page While Fetching All, Always Fetches Previous Page After Fetching All")
  func fetchPreviousPageWhileFetchingAllAlwaysFetchesPreviousPageAfterFetchingAll() async throws {
    let query = WaitableInfiniteQuery()
    let store = self.client.store(for: query)

    query.state.withLock {
      $0.values = [0: "blob", -1: "blob jr", -2: "blob sr", -3: "d"]
    }
    for _ in 0..<3 {
      try await store.fetchPreviousPage()
    }

    query.state.withLock {
      $0.values = [-2: "a", -1: "b", 2: "c", -3: "d"]
      $0.nextPageIds = [-1: 2]
      $0.willWait = true
    }
    let all = Task { try await store.fetchAllPages() }
    try await query.waitForLoading()
    let next = Task { try await store.fetchPreviousPage() }
    try await query.waitForLoading()
    let pages = try await all.value
    await query.advance()
    let page = try await next.value

    expectNoDifference(
      pages,
      [
        InfiniteQueryPage(id: -2, value: "a"),
        InfiniteQueryPage(id: -1, value: "b"),
        InfiniteQueryPage(id: 2, value: "c")
      ]
    )
    expectNoDifference(page, InfiniteQueryPage(id: -3, value: "d"))
    expectNoDifference(
      store.state.currentValue,
      [
        InfiniteQueryPage(id: -3, value: "d"),
        InfiniteQueryPage(id: -2, value: "a"),
        InfiniteQueryPage(id: -1, value: "b"),
        InfiniteQueryPage(id: 2, value: "c")
      ]
    )
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Fetch Next Page While Fetching Previous, Fetches Concurrently")
  func fetchNextPageWhileFetchingPreviousFetchesConcurrently() async throws {
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query)

    query.state.withLock { $0 = [0: "blob", 1: "b", -1: "c"] }
    try await store.fetchNextPage()

    async let previous = store.fetchPreviousPage()
    async let next = store.fetchNextPage()
    let (previousPage, nextPage) = try await (previous, next)

    expectNoDifference(previousPage, InfiniteQueryPage(id: -1, value: "c"))
    expectNoDifference(nextPage, InfiniteQueryPage(id: 1, value: "b"))
    expectNoDifference(
      store.state.currentValue,
      [
        InfiniteQueryPage(id: -1, value: "c"),
        InfiniteQueryPage(id: 0, value: "blob"),
        InfiniteQueryPage(id: 1, value: "b")
      ]
    )
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Fetch From Regular QueryStore, Fetches All")
  func fetchFromRegularQueryStoreFetchesAll() async throws {
    let query = TestInfiniteQuery()
    let infiniteStore = self.client.store(for: query)

    query.state.withLock { $0 = [0: "blob", 1: "b", -1: "c"] }
    try await infiniteStore.fetchNextPage()
    try await infiniteStore.fetchNextPage()
    try await infiniteStore.fetchPreviousPage()

    let store = QueryStoreFor<TestInfiniteQuery>(casting: self.client.store(with: query.path)!)!

    query.state.withLock { $0 = [0: "a", 1: "c", -1: "d"] }
    try await store.fetch()

    expectNoDifference(
      store.currentValue,
      [
        InfiniteQueryPage(id: -1, value: "d"),
        InfiniteQueryPage(id: 0, value: "a"),
        InfiniteQueryPage(id: 1, value: "c")
      ]
    )
    expectNoDifference(store.status.isSuccessful, true)
  }

  @Test("Fetch From Regular QueryStore, Fetches Initial Page When No Fetched Pages")
  func fetchFromRegularQueryStoreFetchesInitialPage() async throws {
    let query = TestInfiniteQuery()
    _ = self.client.store(for: query)
    let store = QueryStoreFor<TestInfiniteQuery>(casting: self.client.store(with: query.path)!)!

    query.state.withLock { $0 = [0: "a", 1: "c", -1: "d"] }
    try await store.fetch()

    expectNoDifference(store.currentValue, [InfiniteQueryPage(id: 0, value: "a")])
    expectNoDifference(store.status.isSuccessful, true)
    expectNoDifference(store.hasNextPage, true)
    expectNoDifference(store.hasPreviousPage, true)
  }

  @Test("Fetch Next Page Events")
  func fetchNextPageEvents() async throws {
    let collector = InfiniteQueryStoreEventsCollector<Int, String>()
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query)
    query.state.withLock { $0 = [0: "a"] }
    try await store.fetchNextPage(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .success(InfiniteQueryPage(id: 0, value: "a"))),
      .pageFetchingEnded(0),
      .resultReceived(.success([InfiniteQueryPage(id: 0, value: "a")])),
      .fetchingEnded
    ])
  }

  @Test("Fetch Next Page Failing Events")
  func fetchNextPageFailingEvents() async throws {
    let collector = InfiniteQueryStoreEventsCollector<Int, String>()
    let store = self.client.store(for: FailableInfiniteQuery())
    _ = try? await store.fetchNextPage(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .failure(FailableInfiniteQuery.SomeError())),
      .pageFetchingEnded(0),
      .resultReceived(.failure(FailableInfiniteQuery.SomeError())),
      .fetchingEnded
    ])
  }

  @Test("Fetch Previous Page Events")
  func fetchPreviousPageEvents() async throws {
    let collector = InfiniteQueryStoreEventsCollector<Int, String>()
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query)
    query.state.withLock { $0 = [0: "a"] }
    try await store.fetchPreviousPage(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .success(InfiniteQueryPage(id: 0, value: "a"))),
      .pageFetchingEnded(0),
      .resultReceived(.success([InfiniteQueryPage(id: 0, value: "a")])),
      .fetchingEnded
    ])
  }

  @Test("Fetch Previous Page Failing Events")
  func fetchPreviousPageFailingEvents() async throws {
    let collector = InfiniteQueryStoreEventsCollector<Int, String>()
    let store = self.client.store(for: FailableInfiniteQuery())
    _ = try? await store.fetchPreviousPage(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .failure(FailableInfiniteQuery.SomeError())),
      .pageFetchingEnded(0),
      .resultReceived(.failure(FailableInfiniteQuery.SomeError())),
      .fetchingEnded
    ])
  }

  @Test("Fetch All Pages Events")
  func fetchAllPagesEvents() async throws {
    let collector = InfiniteQueryStoreEventsCollector<Int, String>()
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query)
    query.state.withLock { $0 = [0: "a", 1: "b"] }
    try await store.fetchNextPage()
    try await store.fetchNextPage()
    try await store.fetchAllPages(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .success(InfiniteQueryPage(id: 0, value: "a"))),
      .pageFetchingEnded(0),
      .pageFetchingStarted(1),
      .pageResultReceived(1, .success(InfiniteQueryPage(id: 1, value: "b"))),
      .pageFetchingEnded(1),
      .resultReceived(
        .success([InfiniteQueryPage(id: 0, value: "a"), InfiniteQueryPage(id: 1, value: "b")])
      ),
      .fetchingEnded
    ])
  }

  @Test("Fetch All Pages Failing Events")
  func fetchAllPagesFailingEvents() async throws {
    let collector = InfiniteQueryStoreEventsCollector<Int, String>()
    let query = FailableInfiniteQuery()
    let store = self.client.store(for: query)
    query.state.withLock { $0 = "test" }
    try await store.fetchNextPage()
    try await store.fetchNextPage()

    query.state.withLock { $0 = nil }
    _ = try? await store.fetchAllPages(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .failure(FailableInfiniteQuery.SomeError())),
      .pageFetchingEnded(0),
      .resultReceived(.failure(FailableInfiniteQuery.SomeError())),
      .fetchingEnded
    ])
  }

  @Test("Fetch Through Normal Query Store Events")
  func fetchThroughNormalQueryStoreEvents() async throws {
    let collector = InfiniteQueryStoreEventsCollector<Int, String>()
    let query = TestInfiniteQuery()
    let infiniteStore = self.client.store(for: query)
    query.state.withLock { $0 = [0: "a", 1: "b"] }
    try await infiniteStore.fetchNextPage()
    try await infiniteStore.fetchNextPage()

    let subscription = infiniteStore.subscribe(with: collector.eventHandler())

    let store = QueryStoreFor<TestInfiniteQuery>(casting: self.client.store(with: query.path)!)!
    try await store.fetch()

    collector.expectEventsMatch([
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .success(InfiniteQueryPage(id: 0, value: "a"))),
      .pageFetchingEnded(0),
      .pageFetchingStarted(1),
      .pageResultReceived(1, .success(InfiniteQueryPage(id: 1, value: "b"))),
      .pageFetchingEnded(1),
      .resultReceived(
        .success([InfiniteQueryPage(id: 0, value: "a"), InfiniteQueryPage(id: 1, value: "b")])
      ),
      .fetchingEnded
    ])
    subscription.cancel()
  }

  @Test("Subscribe To Infinite Query")
  func subscribeToInfiniteQuery() async throws {
    let collector = InfiniteQueryStoreEventsCollector<Int, String>()
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query)
    query.state.withLock { $0 = [0: "a"] }
    let subscription = store.subscribe(with: collector.eventHandler())
    try await store.fetchNextPage()

    collector.expectEventsMatch([
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .success(InfiniteQueryPage(id: 0, value: "a"))),
      .pageFetchingEnded(0),
      .resultReceived(.success([InfiniteQueryPage(id: 0, value: "a")])),
      .fetchingEnded
    ])
    subscription.cancel()
  }
}
