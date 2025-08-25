import CustomDump
import Dependencies
import OperationTestHelpers
import SharingOperation
import Testing

@Suite("RaceCondition tests")
struct RaceConditionTests {
  @Test("Race Condition")
  func raceCondition() async throws {
    @Dependency(\.defaultQueryClient) var client

    let t1 = Task { @MainActor in
      @SharedQuery(TestQuery()) var q1
      return try await $q1.fetch()
    }
    let t2 = Task {
      let store = client.store(for: TestQuery())
      return try await store.fetch()
    }
    let (v1, v2) = try await (t1.value, t2.value)
    expectNoDifference(v1, TestQuery.value)
    expectNoDifference(v2, TestQuery.value)
  }
}
