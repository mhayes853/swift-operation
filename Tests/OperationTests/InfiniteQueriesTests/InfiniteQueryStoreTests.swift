import CustomDump
import Foundation
import Operation
import OperationTestHelpers
import Testing

@Suite("InfiniteOperationStore tests")
struct InfiniteOperationStoreTests {
  private let client = OperationClient()

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
    Task { try await store.refetchAllPages() }
    try await query.waitForLoading()
  }

  @Test("Returns Empty Array When No Pages After Fetching All Pages")
  func emptyArrayWhenNoPagesAfterFetchingAllPages() async throws {
    let store = self.client.store(for: TestInfiniteQuery())
    let pages = try await store.refetchAllPages()
    expectNoDifference(pages, [])
    expectNoDifference(store.state.currentValue, [])
    expectNoDifference(store.state.status.isSuccessful, true)
  }

  @Test("Has Next And Previous Page After Fetching All Pages When Empty")
  func hasNextAndPreviousPageAfterFetchingAllPagesWhenEmpty() async throws {
    let store = self.client.store(for: TestInfiniteQuery())
    try await store.refetchAllPages()
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
    let pages = try await store.refetchAllPages()

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
    let pages = try await store.refetchAllPages()
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
    let pages = try await store.refetchAllPages()

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

  @Test("Fetch All Pages With Task After Fetching Some, Starts From Earliest Page")
  func fetchAllPagesWithTaskAfterFetchingSomeStartsFromEarliestPage() async throws {
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query)

    query.state.withLock { $0 = [-1: "c", 0: "a", 1: "b"] }
    try await store.fetchNextPage()
    try await store.fetchNextPage()

    query.state.withLock { $0 = [-1: "d", 0: "e", 1: "f"] }
    try await store.fetchPreviousPage()
    let task = store.refetchAllPagesTask()
    let pages = try await task.runIfNeeded()

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

  @Test("Is Loading Initial When Fetching Next Page When No Pages")
  func isLoadingInitialWhenFetchingNextPageWhenNoPages() async throws {
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
        expectNoDifference(store.state.isLoadingNextPage, false)
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

  @Test("Fetch Next Page With Task, Returns Page Data For Next Page After First")
  func fetchNextPageWithTaskReturnsPageDataForNextPageAfterFirst() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock { $0 = [0: "blob", 1: "blob jr"] }
    let store = self.client.store(for: query)

    try await store.fetchNextPage()
    expectNoDifference(store.hasNextPage, true)
    expectNoDifference(store.hasPreviousPage, false)

    let task = store.fetchNextPageTask()
    let page = try await task.runIfNeeded()
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

  @Test("Is Loading Initial When Fetching Previous Page With No Pages")
  func isLoadingInitialWhenFetchingPreviousPage() async throws {
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
        expectNoDifference(store.isLoadingPreviousPage, false)
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

  @Test("Fetch Previous Page With Task, Returns Page Data Before First")
  func fetchPreviousPageWithTaskReturnsPageDataBeforeFirst() async throws {
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query)

    query.state.withLock { $0 = [0: "blob", -1: "blob jr"] }
    try await store.fetchPreviousPage()
    expectNoDifference(store.hasNextPage, false)
    expectNoDifference(store.hasPreviousPage, true)

    let task = store.fetchPreviousPageTask()
    let page = try await task.runIfNeeded()

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
      $0.shouldStallIfWaiting = false
    }
    let all = Task { try await store.refetchAllPages() }
    try await query.waitForLoading()
    query.state.withLock { $0.willWait = false }
    let next = Task { try await store.fetchNextPage() }
    let pages = try await all.value
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
      $0.shouldStallIfWaiting = false
    }
    let all = Task { try await store.refetchAllPages() }
    try await query.waitForLoading()
    query.state.withLock { $0.willWait = false }
    let next = Task { try await store.fetchPreviousPage() }
    let pages = try await all.value
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
    let store = self.client.store(for: query.deduplicated())

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

  @Test("Fetch From Regular OperationStore, Refetches Initial Page")
  func fetchFromRegularOperationStoreRefetchesInitialPage() async throws {
    let query = TestInfiniteQuery()
    let infiniteStore = self.client.store(for: query)

    query.state.withLock { $0 = [0: "blob", 1: "b", -1: "c"] }
    try await infiniteStore.fetchNextPage()
    try await infiniteStore.fetchNextPage()
    try await infiniteStore.fetchPreviousPage()

    let store =
      self.client.store(with: query.path)!.base as! OperationStore<TestInfiniteQuery.State>

    query.state.withLock { $0 = [0: "a", 1: "c", -1: "d"] }
    try await store.run()

    expectNoDifference(store.currentValue, [InfiniteQueryPage(id: 0, value: "a")])
    expectNoDifference(store.status.isSuccessful, true)
  }

  @Test("Fetch Next Page Events")
  func fetchNextPageEvents() async throws {
    let collector = InfiniteOperationStoreEventsCollector<TestInfiniteQuery.State>()
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query)
    query.state.withLock { $0 = [0: "a"] }
    try await store.fetchNextPage(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .success(InfiniteQueryPage(id: 0, value: "a"))),
      .pageFetchingEnded(0),
      .resultReceived(.success([InfiniteQueryPage(id: 0, value: "a")])),
      .stateChanged,
      .fetchingEnded
    ])
  }

  @Test("Fetch Next Page Failing Events")
  func fetchNextPageFailingEvents() async throws {
    let collector = InfiniteOperationStoreEventsCollector<FailableInfiniteQuery.State>()
    let store = self.client.store(for: FailableInfiniteQuery())
    _ = try? await store.fetchNextPage(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .failure(FailableInfiniteQuery.SomeError())),
      .pageFetchingEnded(0),
      .resultReceived(.failure(FailableInfiniteQuery.SomeError())),
      .stateChanged,
      .fetchingEnded
    ])
  }

  @Test("Fetch Previous Page Events")
  func fetchPreviousPageEvents() async throws {
    let collector = InfiniteOperationStoreEventsCollector<TestInfiniteQuery.State>()
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query)
    query.state.withLock { $0 = [0: "a"] }
    try await store.fetchPreviousPage(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .success(InfiniteQueryPage(id: 0, value: "a"))),
      .pageFetchingEnded(0),
      .resultReceived(.success([InfiniteQueryPage(id: 0, value: "a")])),
      .stateChanged,
      .fetchingEnded
    ])
  }

  @Test("Fetch Previous Page Failing Events")
  func fetchPreviousPageFailingEvents() async throws {
    let collector = InfiniteOperationStoreEventsCollector<FailableInfiniteQuery.State>()
    let store = self.client.store(for: FailableInfiniteQuery())
    _ = try? await store.fetchPreviousPage(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .failure(FailableInfiniteQuery.SomeError())),
      .pageFetchingEnded(0),
      .resultReceived(.failure(FailableInfiniteQuery.SomeError())),
      .stateChanged,
      .fetchingEnded
    ])
  }

  @Test("Fetch All Pages Events")
  func fetchAllPagesEvents() async throws {
    let collector = InfiniteOperationStoreEventsCollector<TestInfiniteQuery.State>()
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query)
    query.state.withLock { $0 = [0: "a", 1: "b"] }
    try await store.fetchNextPage()
    try await store.fetchNextPage()
    try await store.refetchAllPages(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .stateChanged,
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
      .stateChanged,
      .fetchingEnded
    ])
  }

  @Test("Fetch All Pages Failing Events")
  func fetchAllPagesFailingEvents() async throws {
    let collector = InfiniteOperationStoreEventsCollector<FailableInfiniteQuery.State>()
    let query = FailableInfiniteQuery()
    let store = self.client.store(for: query)
    query.state.withLock { $0 = "test" }
    try await store.fetchNextPage()
    try await store.fetchNextPage()

    query.state.withLock { $0 = nil }
    _ = try? await store.refetchAllPages(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .failure(FailableInfiniteQuery.SomeError())),
      .pageFetchingEnded(0),
      .resultReceived(.failure(FailableInfiniteQuery.SomeError())),
      .stateChanged,
      .fetchingEnded
    ])
  }

  @Test("Fetch Through Normal Query Store Events")
  func fetchThroughNormalOperationStoreEvents() async throws {
    let collector = InfiniteOperationStoreEventsCollector<TestInfiniteQuery.State>()
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query.disableAutomaticRunning())
    query.state.withLock { $0 = [0: "a", 1: "b"] }
    try await store.fetchNextPage()
    try await store.fetchNextPage()

    let subscription = store.subscribe(with: collector.eventHandler())
    try await store.run()

    collector.expectEventsMatch([
      .stateChanged,
      .stateChanged,
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .success(InfiniteQueryPage(id: 0, value: "a"))),
      .pageFetchingEnded(0),
      .resultReceived(.success([InfiniteQueryPage(id: 0, value: "a")])),
      .stateChanged,
      .fetchingEnded
    ])
    subscription.cancel()
  }

  @Test("Subscribe To Infinite Query")
  func subscribeToInfiniteQuery() async throws {
    let collector = InfiniteOperationStoreEventsCollector<TestInfiniteQuery.State>()
    let query = TestInfiniteQuery()
    let store = self.client.store(for: query)
    query.state.withLock { $0 = [0: "a"] }
    let subscription = store.subscribe(with: collector.eventHandler())
    _ = try? await store.initialPageActiveTasks.first?.runIfNeeded()

    collector.expectEventsMatch([
      .stateChanged,
      .stateChanged,
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .success(InfiniteQueryPage(id: 0, value: "a"))),
      .pageFetchingEnded(0),
      .resultReceived(.success([InfiniteQueryPage(id: 0, value: "a")])),
      .stateChanged,
      .fetchingEnded
    ])
    subscription.cancel()
  }

  @Test("Default FetchAll InfiniteOperationStore Task Name")
  func defaultInfiniteOperationStoreName() async throws {
    let store = self.client.store(for: EmptyInfiniteQuery(initialPageId: 0, path: []))
    let task = store.refetchAllPagesTask()
    expectNoDifference(
      task.configuration.name,
      "OperationStore<InfiniteQueryState<Int, String, Error>> Fetch All Pages Task"
    )
  }

  @Test("Default FetchNext InfiniteOperationStore Task Name")
  func defaultFetchNextInfiniteOperationStoreName() async throws {
    let store = self.client.store(for: EmptyInfiniteQuery(initialPageId: 0, path: []))
    let task = store.fetchNextPageTask()
    expectNoDifference(
      task.configuration.name,
      "OperationStore<InfiniteQueryState<Int, String, Error>> Fetch Next Page Task"
    )
  }

  @Test("Default FetchPrevious InfiniteOperationStore Task Name")
  func defaultFetchPreviousInfiniteOperationStoreName() async throws {
    let store = self.client.store(for: EmptyInfiniteQuery(initialPageId: 0, path: []))
    let task = store.fetchPreviousPageTask()
    expectNoDifference(
      task.configuration.name,
      "OperationStore<InfiniteQueryState<Int, String, Error>> Fetch Previous Page Task"
    )
  }

  @Test("Controller Yields New State Value To Infinite Query")
  func yieldsNewStateValueToInfiniteQuery() async throws {
    let controller = TestOperationController<TestInfiniteQuery>()
    let store =
      OperationStore.detached(query: TestInfiniteQuery().controlled(by: controller))

    let date = RecursiveLock(Date())
    store.context.operationClock = CustomOperationClock { date.withLock { $0 } }

    controller.controls.withLock { $0?.yield([InfiniteQueryPage(id: 0, value: "blob")]) }
    expectNoDifference(store.currentValue, [InfiniteQueryPage(id: 0, value: "blob")])
    expectNoDifference(store.valueUpdateCount, 1)
    expectNoDifference(store.valueLastUpdatedAt, date.withLock { $0 })

    date.withLock { $0 = .distantFuture }
    controller.controls.withLock { $0?.yield([]) }
    expectNoDifference(store.currentValue, [])
    expectNoDifference(store.valueUpdateCount, 2)
    expectNoDifference(store.valueLastUpdatedAt, .distantFuture)
  }

  @Test("Controller Yields New State Value To Infinite Query While Fetching Initial Page")
  func yieldsNewStateValueToInfiniteQueryWhileFetchingInitialPage() async throws {
    let controller = TestOperationController<TestInfiniteQuery>()
    let query = WaitableInfiniteQuery()
    query.state.withLock {
      $0.values = [0: "vlov"]
      $0.willWait = true
    }
    let store =
      OperationStore.detached(query: query.controlled(by: controller))

    let task = Task { try await store.fetchNextPage() }
    try await query.waitForLoading()

    controller.controls.withLock { $0?.yield([InfiniteQueryPage(id: 0, value: "blob")]) }
    expectNoDifference(store.currentValue, [InfiniteQueryPage(id: 0, value: "blob")])

    await query.advance()
    _ = try await task.value

    expectNoDifference(store.currentValue, [InfiniteQueryPage(id: 0, value: "vlov")])
  }

  @Test("Controller Yields New State Value To Infinite Query While Fetching Next Page")
  func yieldsNewStateValueToInfiniteQueryWhileFetchingNextPage() async throws {
    let controller = TestOperationController<TestInfiniteQuery>()
    let query = WaitableInfiniteQuery()
    query.state.withLock {
      $0.values = [0: "vlov", 1: "trov"]
      $0.willWait = false
    }
    let store =
      OperationStore.detached(query: query.controlled(by: controller))
    try await store.fetchNextPage()
    query.state.withLock { $0.willWait = true }

    let task = Task { try await store.fetchNextPage() }
    try await query.waitForLoading()

    controller.controls.withLock { $0?.yield([InfiniteQueryPage(id: 10, value: "blob")]) }
    expectNoDifference(store.currentValue, [InfiniteQueryPage(id: 10, value: "blob")])

    await query.advance()
    _ = try await task.value

    expectNoDifference(store.currentValue, [InfiniteQueryPage(id: 10, value: "blob")])
  }

  @Test("ControllerYields New Error Value To Infinite Query")
  func yieldsNewErrorValueToInfiniteQuery() async throws {
    let controller = TestOperationController<TestInfiniteQuery>()
    let store =
      OperationStore.detached(query: TestInfiniteQuery().controlled(by: controller))

    let date = RecursiveLock(Date())
    store.context.operationClock = CustomOperationClock { date.withLock { $0 } }

    struct SomeError: Equatable, Error {}

    controller.controls.withLock { $0?.yield(throwing: SomeError()) }
    expectNoDifference(store.error as? SomeError, SomeError())
    expectNoDifference(store.errorUpdateCount, 1)
    expectNoDifference(store.errorLastUpdatedAt, date.withLock { $0 })
  }

  @Test("Yields Multiple Values During Query For Initial Page")
  func yieldsMultipleValuesDuringQueryForInitialPage() async throws {
    let query = TestYieldableInfiniteQuery()
    query.state.withLock { $0[0] = [.success("blob"), .success("blob jr")] }
    let store = self.client.store(for: query)
    let collector = InfiniteOperationStoreEventsCollector<TestYieldableInfiniteQuery.State>()
    let value = try await store.fetchNextPage(handler: collector.eventHandler())
    let finalPage = InfiniteQueryPage(id: 0, value: TestYieldableInfiniteQuery.finalValue(for: 0))

    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .success(InfiniteQueryPage(id: 0, value: "blob"))),
      .stateChanged,
      .pageResultReceived(0, .success(InfiniteQueryPage(id: 0, value: "blob jr"))),
      .stateChanged,
      .pageResultReceived(0, .success(finalPage)),
      .pageFetchingEnded(0),
      .resultReceived(.success([finalPage])),
      .stateChanged,
      .fetchingEnded
    ])
    expectNoDifference(value, finalPage)
    expectNoDifference(store.currentValue, [finalPage])
  }

  @Test("Yields Multiple Values During Query For Next Page")
  func yieldsMultipleValuesDuringQueryForNextPage() async throws {
    let query = TestYieldableInfiniteQuery()
    query.state.withLock { $0[1] = [.success("blob"), .success("blob jr")] }
    let store = self.client.store(for: query)
    let collector = InfiniteOperationStoreEventsCollector<TestYieldableInfiniteQuery.State>()
    try await store.fetchNextPage()
    let value = try await store.fetchNextPage(handler: collector.eventHandler())
    let finalPage = TestYieldableInfiniteQuery.finalPage(for: 1)
    let firstPage = TestYieldableInfiniteQuery.finalPage(for: 0)

    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .pageFetchingStarted(1),
      .pageResultReceived(1, .success(InfiniteQueryPage(id: 1, value: "blob"))),
      .stateChanged,
      .pageResultReceived(1, .success(InfiniteQueryPage(id: 1, value: "blob jr"))),
      .stateChanged,
      .pageResultReceived(1, .success(finalPage)),
      .pageFetchingEnded(1),
      .resultReceived(.success([firstPage, finalPage])),
      .stateChanged,
      .fetchingEnded
    ])
    expectNoDifference(value, finalPage)
    expectNoDifference(store.currentValue, [firstPage, finalPage])
  }

  @Test("Yields Multiple Values During Query For Previous Page")
  func yieldsMultipleValuesDuringQueryForPreviousPage() async throws {
    let query = TestYieldableInfiniteQuery()
    query.state.withLock { $0[-1] = [.success("blob"), .success("blob jr")] }
    let store = self.client.store(for: query)
    let collector = InfiniteOperationStoreEventsCollector<TestYieldableInfiniteQuery.State>()
    try await store.fetchPreviousPage()
    let value = try await store.fetchPreviousPage(handler: collector.eventHandler())
    let finalPage = TestYieldableInfiniteQuery.finalPage(for: -1)
    let firstPage = TestYieldableInfiniteQuery.finalPage(for: 0)

    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .pageFetchingStarted(-1),
      .pageResultReceived(-1, .success(InfiniteQueryPage(id: -1, value: "blob"))),
      .stateChanged,
      .pageResultReceived(-1, .success(InfiniteQueryPage(id: -1, value: "blob jr"))),
      .stateChanged,
      .pageResultReceived(-1, .success(finalPage)),
      .pageFetchingEnded(-1),
      .resultReceived(.success([finalPage, firstPage])),
      .stateChanged,
      .fetchingEnded
    ])
    expectNoDifference(value, finalPage)
    expectNoDifference(store.currentValue, [finalPage, firstPage])
  }

  @Test("Yields Multiple Values During Query For All Pages")
  func yieldsMultipleValuesDuringQueryForAllPages() async throws {
    struct SomeError: Error {}

    let query = TestYieldableInfiniteQuery()
    query.state.withLock {
      $0[0] = [.success("blob"), .success("blob jr")]
      $0[1] = [.success("trob"), .failure(SomeError())]
    }
    let store = self.client.store(for: query)
    let collector = InfiniteOperationStoreEventsCollector<TestYieldableInfiniteQuery.State>()
    try await store.fetchNextPage()
    try await store.fetchNextPage()
    let value = try await store.refetchAllPages(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .success(InfiniteQueryPage(id: 0, value: "blob"))),
      .stateChanged,
      .pageResultReceived(0, .success(InfiniteQueryPage(id: 0, value: "blob jr"))),
      .stateChanged,
      .pageResultReceived(0, .success(TestYieldableInfiniteQuery.finalPage(for: 0))),
      .pageFetchingEnded(0),
      .pageFetchingStarted(1),
      .pageResultReceived(1, .success(InfiniteQueryPage(id: 1, value: "trob"))),
      .stateChanged,
      .pageResultReceived(1, .failure(SomeError())),
      .stateChanged,
      .pageResultReceived(1, .success(TestYieldableInfiniteQuery.finalPage(for: 1))),
      .pageFetchingEnded(1),
      .resultReceived(.success(value)),
      .stateChanged,
      .fetchingEnded
    ])
    expectNoDifference(
      value,
      [TestYieldableInfiniteQuery.finalPage(for: 0), TestYieldableInfiniteQuery.finalPage(for: 1)]
    )
    expectNoDifference(store.errorLastUpdatedAt != nil, true)
    expectNoDifference(store.currentValue, value)
  }

  @Test("Yields Value Then Error During Query")
  func yieldsValueThenErrorDuringQuery() async throws {
    let query = TestYieldableInfiniteQuery(shouldThrow: true)
    query.state.withLock { $0[0] = [.success("blob")] }
    let store = self.client.store(for: query)
    let collector = InfiniteOperationStoreEventsCollector<TestYieldableInfiniteQuery.State>()
    let value = try? await store.fetchPreviousPage(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .pageFetchingStarted(0),
      .pageResultReceived(0, .success(InfiniteQueryPage(id: 0, value: "blob"))),
      .stateChanged,
      .pageResultReceived(0, .failure(TestYieldableInfiniteQuery.SomeError())),
      .pageFetchingEnded(0),
      .resultReceived(.failure(TestYieldableInfiniteQuery.SomeError())),
      .stateChanged,
      .fetchingEnded
    ])
    expectNoDifference(value, nil)
    expectNoDifference(
      store.error as? TestYieldableInfiniteQuery.SomeError,
      TestYieldableInfiniteQuery.SomeError()
    )
  }

  @Test("Reset State, Cancels All Active Tasks")
  func resetStateCancelsAllActiveTasks() async throws {
    let store = self.client.store(for: TestCancellableInfiniteQuery())
    let task = store.fetchNextPageTask()
    store.resetState()
    await #expect(throws: CancellationError.self) {
      try await task.runIfNeeded()
    }
  }

  @Test("Reset State, Removes All Active Tasks")
  func resetStateRemovesAllActiveTasks() async throws {
    let store = self.client.store(for: TestYieldableInfiniteQuery())
    try await store.fetchNextPage()
    let task = store.fetchNextPageTask()
    let task2 = store.fetchPreviousPageTask()
    let task3 = store.refetchAllPagesTask()
    expectNoDifference(store.nextPageActiveTasks.count, 1)
    expectNoDifference(store.previousPageActiveTasks.count, 1)
    expectNoDifference(store.allPagesActiveTasks.count, 1)
    store.resetState()
    expectNoDifference(store.nextPageActiveTasks.count, 0)
    expectNoDifference(store.previousPageActiveTasks.count, 0)
    expectNoDifference(store.allPagesActiveTasks.count, 0)
    _ = task
    _ = task2
    _ = task3
  }

  @Test("Reset State, Resets State Values")
  func resetStateResetsStateValues() async throws {
    let store = self.client.store(for: TestYieldableInfiniteQuery())
    try await store.fetchNextPage()
    expectNoDifference(store.currentValue, [TestYieldableInfiniteQuery.finalPage(for: 0)])
    expectNoDifference(store.valueUpdateCount, 1)
    expectNoDifference(store.valueLastUpdatedAt != nil, true)
    store.resetState()
    expectNoDifference(store.currentValue, [])
    expectNoDifference(store.valueUpdateCount, 0)
    expectNoDifference(store.valueLastUpdatedAt == nil, true)
  }

  @Test("Includes Yielded Update Reason In Page Result Events")
  func includesYieldedUpdateReasonInPageResultEvents() async throws {
    let store = self.client.store(for: FailableInfiniteQuery(shouldYield: true))

    _ = await confirmation { confirm in
      await #expect(throws: Error.self) {
        try await store.fetchNextPage(
          handler: InfiniteQueryEventHandler(
            onPageResultReceived: { _, _, context in
              guard context.operationResultUpdateReason == .yieldedResult else { return }
              confirm()
            }
          )
        )
      }
    }
  }

  @Test("Includes Final Result Update Reason In Page Result Events")
  func includesFinalResultUpdateReasonInPageResultEvents() async throws {
    let store = self.client.store(for: FailableInfiniteQuery())

    _ = await confirmation { confirm in
      await #expect(throws: Error.self) {
        try await store.fetchNextPage(
          handler: InfiniteQueryEventHandler(
            onPageResultReceived: { _, _, context in
              guard context.operationResultUpdateReason == .returnedFinalResult else { return }
              confirm()
            }
          )
        )
      }
    }
  }

  @Test("Uses Default Value When Value Never Been Set")
  func usesDefaultValueWhenValueNeverBeenSet() {
    let page = InfiniteQueryPage(id: 0, value: "blob")
    let page2 = InfiniteQueryPage(id: 0, value: "blob 2")
    let store = self.client.store(for: FailableInfiniteQuery().defaultValue([page]))

    expectNoDifference(store.currentValue, [page])
    store.currentValue = [page2]
    expectNoDifference(store.currentValue, [page2])
    store.currentValue = []
    expectNoDifference(store.currentValue, [])
  }
}
