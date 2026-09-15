import CustomDump
import Operation
import OperationTestHelpers
import Testing

@Suite("PaginatedStore Context tests")
struct PaginatedStoreContextTests {
  @Test
  func `Fetches The Next Page Using A Custom Context`() async throws {
    let query = TestPaginated()
    query.state.withLock { $0 = [0: "blob", 1: "blob jr"] }
    let store = OperationClient().store(for: query)
    try await store.fetchNextPage()

    let page = try await store.fetchNextPage(using: OperationContext())

    expectNoDifference(page, Page(id: 1, value: "blob jr"))
    expectNoDifference(
      store.currentValue,
      [Page(id: 0, value: "blob"), Page(id: 1, value: "blob jr")]
    )
  }

  @Test
  func `Fetches The Previous Page Using A Custom Context`() async throws {
    let query = TestPaginated()
    query.state.withLock { $0 = [-1: "blob sr", 0: "blob"] }
    let store = OperationClient().store(for: query)
    try await store.fetchNextPage()

    let page = try await store.fetchPreviousPage(using: OperationContext())

    expectNoDifference(page, Page(id: -1, value: "blob sr"))
    expectNoDifference(
      store.currentValue,
      [Page(id: -1, value: "blob sr"), Page(id: 0, value: "blob")]
    )
  }

  @Test
  func `Refetches All Pages Using A Custom Context`() async throws {
    let query = TestPaginated()
    query.state.withLock { $0 = [0: "blob", 1: "blob jr"] }
    let store = OperationClient().store(for: query)
    try await store.fetchNextPage()
    try await store.fetchNextPage()
    query.state.withLock { $0 = [0: "blob sr", 1: "blob III"] }

    let pages = try await store.refetchAllPages(using: OperationContext())

    expectNoDifference(
      pages,
      [Page(id: 0, value: "blob sr"), Page(id: 1, value: "blob III")]
    )
  }
}
