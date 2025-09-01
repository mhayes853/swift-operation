import CustomDump
import Dependencies
import OperationTestHelpers
import SharingOperation
import Testing

@Suite("PaginatedKey tests")
struct PaginatedKeyTests {
  @Test("Fetches For Value")
  func fetchesForValue() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock { $0 = [0: "hello", 1: "world"] }
    @SharedOperation(query.disableAutomaticRunning()) var value = []

    expectNoDifference(value, [])

    try await $value.fetchNextPage()
    expectNoDifference(value, [Page(id: 0, value: "hello")])

    try await $value.fetchNextPage()
    expectNoDifference(
      value,
      [Page(id: 0, value: "hello"), Page(id: 1, value: "world")]
    )
  }

  @Test("Fetches For Error")
  func fetchesForError() async throws {
    @SharedOperation(FailableInfiniteQuery().disableAutomaticRunning())
    var value

    expectNoDifference($value.error as? FailableInfiniteQuery.SomeError, nil)
    _ = try? await $value.fetchNextPage()
    expectNoDifference(
      $value.error as? FailableInfiniteQuery.SomeError,
      FailableInfiniteQuery.SomeError()
    )
  }
}
