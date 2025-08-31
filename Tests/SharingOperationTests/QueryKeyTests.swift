import CustomDump
import Dependencies
@_spi(Warnings) import OperationTestHelpers
@_spi(Warnings) import SharingOperation
import Testing

@Suite("QueryKey tests")
struct QueryKeyTests {
  @Test("Nil Value Initially")
  func nilValueInitially() async throws {
    @Dependency(\.defaultOperationClient) var client
    @SharedOperation(EndlessQuery()) var value

    expectNoDifference(value, nil)
  }

  @Test("Fetches Value")
  func fetchesValue() async throws {
    @Dependency(\.defaultOperationClient) var client

    let query = TestQuery()
    @SharedOperation(query) var value

    _ = try await client.store(for: query).activeTasks.first?.runIfNeeded()
    expectNoDifference(value, TestQuery.value)
  }

  @Test("Nil Error Initially")
  func nilErrorInitially() async throws {
    @Dependency(\.defaultOperationClient) var client
    @SharedOperation(EndlessQuery()) var value

    expectNoDifference($value.error == nil, true)
  }

  @Test("Fetches Error")
  func fetchesError() async throws {
    @Dependency(\.defaultOperationClient) var client

    let query = FailingQuery()
    @SharedOperation(query) var value

    _ = try? await client.store(for: query).activeTasks.first?.runIfNeeded()
    expectNoDifference($value.error as? FailingQuery.SomeError, FailingQuery.SomeError())
  }

  @Test("Set Value, Updates Value In Store")
  func setValueUpdatesValueInStore() async throws {
    @Dependency(\.defaultOperationClient) var client

    let query = TestQuery().disableAutomaticRunning()
    @SharedOperation(query) var value

    $value.withLock { $0 = TestQuery.value + 1 }
    expectNoDifference(value, TestQuery.value + 1)
    expectNoDifference(client.store(for: query).currentValue, value)
  }

  @Test("Shares State With Shared Queries")
  func sharesStateWithSharedQueries() async throws {
    @Dependency(\.defaultOperationClient) var client

    let query = TestQuery().disableAutomaticRunning()
    @SharedOperation(query) var value
    @SharedOperation(query) var state

    $value.withLock { $0 = TestQuery.value + 1 }
    expectNoDifference(value, TestQuery.value + 1)
    expectNoDifference(state, value)
  }

  @Test("Makes Separate Subscribers When Using QueryKey And OperationStateKey In Conjunction")
  func makesSeparateSubscribersWhenUsingQueryKeyAndOperationStateKeyInConjunction() async throws {
    @Dependency(\.defaultOperationClient) var client

    let query = TestQuery().disableAutomaticRunning()
    @SharedOperation(query) var value
    @SharedOperation(query) var state

    let store = client.store(for: query)
    expectNoDifference(store.subscriberCount, 2)
  }

  @Test("Makes Separate Subscribers When Using QueryKeys With The Same Query")
  func makesSeparateSubscribersWhenUsingQueryKeysWithTheSameQuery() async throws {
    @Dependency(\.defaultOperationClient) var client

    let query = TestQuery().disableAutomaticRunning()
    @SharedOperation(query) var value
    @SharedOperation(query) var state

    let store = client.store(for: query)
    expectNoDifference(store.subscriberCount, 2)
  }

  @Test("Backed Query Is Not Unbacked")
  func backedQueryIsBacked() async throws {
    @SharedOperation(TestQuery().disableAutomaticRunning()) var value
    expectNoDifference($value.isBacked, true)
  }

  @Test("Unbacked Query")
  func unbackedQuery() async throws {
    @SharedOperation<TestQuery.State> var value = TestQuery.value
    expectNoDifference(value, TestQuery.value)
    expectNoDifference($value.isBacked, false)
  }

  @Test("Unbacked Mutation")
  func unbackedMutation() async throws {
    @SharedOperation<EmptyMutation.State> var value = "blob"
    expectNoDifference(value, "blob")
    expectNoDifference($value.isBacked, false)
  }

  #if swift(>=6.2) && SWIFT_OPERATION_EXIT_TESTABLE_PLATFORM
    @Test("Exits When Fetching Unbacked Query")
    func exitsWhenFetchingUnbackedQuery() async throws {
      let comment = Comment(rawValue: _unbackedOperationRunError(stateType: TestQuery.State.self))
      await #expect(processExitsWith: .failure, comment) {
        @SharedOperation<TestQuery.State> var value = TestQuery.value
        try await $value.fetch()
      }
    }
  #endif
}
