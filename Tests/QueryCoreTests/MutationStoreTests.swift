import Clocks
import CustomDump
import QueryCore
import Testing

@Suite("MutationStore tests")
struct MutationStoreTests {
  private let client = QueryClient()

  @Test("Casts To MutationStore From AnyQueryStore")
  func testCastsToMutationStoreFromAnyQueryStore() {
    let store = AnyQueryStore.detached(erasing: EmptyMutation())
    let mutationStore = MutationStoreFor<EmptyMutation>(casting: store)
    expectNoDifference(mutationStore != nil, true)
  }

  @Test("Casts To MutationStore From AnyQueryStore With Modifier")
  func testCastsToMutationStoreFromAnyQueryStoreWithModifier() {
    let store = AnyQueryStore.detached(
      erasing: EmptyMutation().enableAutomaticFetching(when: .fetchManuallyCalled)
    )
    let mutationStore = MutationStoreFor<EmptyMutation>(casting: store)
    expectNoDifference(mutationStore != nil, true)
  }

  @Test(
    "Does Not Cast To MutationStore From AnyQueryStore When Underlying Query Is Not Infinite"
  )
  func testDoesNotCastsToMutationStoreFromAnyQueryStore() {
    let store = AnyQueryStore.detached(
      erasing: FakeInfiniteQuery().defaultValue([]),
      initialValue: FakeInfiniteQuery.Value()
    )
    let mutationStore = MutationStoreFor<EmptyMutation>(casting: store)
    expectNoDifference(mutationStore == nil, true)
  }

  @Test(
    "Does Not Cast To MutationStore From AnyQueryStore When Type Mismatch"
  )
  func testDoesNotCastsToMutationStoreFromAnyQueryStoreWithTypeMismatch() {
    let store = AnyQueryStore.detached(erasing: EmptyIntMutation())
    let mutationStore = MutationStoreFor<EmptyMutation>(casting: store)
    expectNoDifference(mutationStore == nil, true)
  }

  @Test("Mutate Returns Mutated Value")
  func mutate() async throws {
    let mutation = EmptyMutation()
    let store = self.client.store(for: mutation)
    let result = try await store.mutate(with: "blob")
    expectNoDifference(result, "blob")
    expectNoDifference(store.currentValue, "blob")
  }

  @Test("Mutate Adds Value To History")
  func mutateAddsValueToHistory() async throws {
    let mutation = EmptyMutation()
    let store = self.client.store(for: mutation)
    try await store.mutate(with: "blob")
    expectNoDifference(store.history.count, 1)
    expectNoDifference(store.history[0].arguments, "blob")
    expectNoDifference(store.history[0].status.isSuccessful, true)

    try await store.mutate(with: "blob jr")
    expectNoDifference(store.history.count, 2)
    expectNoDifference(store.history[1].arguments, "blob jr")
    expectNoDifference(store.history[1].status.isSuccessful, true)
  }

  @Test("Mutation Is Loading")
  func mutationIsLoading() async throws {
    let mutation = SleepingMutation(clock: ImmediateClock(), duration: .seconds(1))
    let store = self.client.store(for: mutation)
    mutation.didBeginSleeping = {
      expectNoDifference(store.isLoading, true)
    }
    try await store.mutate(with: "blob")
    expectNoDifference(store.isLoading, false)
  }

  @Test("Mutation Is Loading, Adds Loading Status To History")
  func mutationIsLoadingAddsLoadingStatusToHistory() async throws {
    let mutation = SleepingMutation(clock: ImmediateClock(), duration: .seconds(1))
    let store = self.client.store(for: mutation)
    mutation.didBeginSleeping = {
      expectNoDifference(store.history.count, 1)
      expectNoDifference(store.history[0].status.isLoading, true)
      expectNoDifference(store.history[0].arguments, "blob")
    }
    try await store.mutate(with: "blob")
  }

  @Test("Mutation Throws Error")
  func mutationThrowsError() async throws {
    let mutation = FailableMutation()
    let store = self.client.store(for: mutation)
    let result = try? await store.mutate(with: "blob")
    expectNoDifference(store.error != nil, true)
    expectNoDifference(result, nil)
  }

  @Test("Mutation Throws Error, Adds Error Status To History")
  func mutationThrowsErrorAddsErrorStatusToHistory() async throws {
    let mutation = FailableMutation()
    let store = self.client.store(for: mutation)
    _ = try? await store.mutate(with: "blob")
    expectNoDifference(store.history.count, 1)
    expectNoDifference(store.history[0].status.isFailure, true)
    expectNoDifference(store.history[0].arguments, "blob")
  }

  @Test("Can Wait For Individual Historical Mutation")
  func canWaitForIndividualHistoricalMutation() async throws {
    let mutation = WaitableMutation()
    mutation.state.withLock { $0.willWait = true }
    let store = self.client.store(for: mutation)

    let handle = Lock<MutationTask<String>?>(nil)
    mutation.onLoading(for: "blob") {
      handle.withLock { $0 = store.history[0].task }
    }
    Task { try await store.mutate(with: "blob") }
    try await mutation.waitForLoading(on: "blob")

    mutation.state.withLock { $0.willWait = false }
    _ = try? await store.mutate(with: "blob jr")
    expectNoDifference(store.history.map(\.status.isLoading), [true, false])

    let task = try #require(handle.withLock { $0 })
    async let value = task.value
    await mutation.advance(on: "blob")
    _ = try await value
    expectNoDifference(store.history.map(\.status.isLoading), [false, false])
  }

  @Test("Mutation History Finished Date After Start Date")
  func mutationHistoryFinishedDateAfterStartDate() async throws {
    let mutation = WaitableMutation()

    let store = self.client.store(for: mutation)
    mutation.onLoading(for: "blob") {
      expectNoDifference(store.history[0].finishDate, nil)
    }
    _ = try? await store.mutate(with: "blob")
    let endDate = try #require(store.history[0].finishDate)
    expectNoDifference(endDate > store.history[0].startDate, true)
  }

  @Test("Successful Mutation Events")
  func successfulMutationEvents() async throws {
    let store = self.client.store(for: EmptyMutation())
    let collector = MutationStoreEventsCollector<EmptyMutation.Arguments, EmptyMutation.Value>()
    try await store.mutate(with: "blob", handler: collector.eventHandler())

    collector.expectEventsMatch([
      .mutatingStarted("blob"),
      .mutationResultReceived("blob", .success("blob")),
      .mutatingEnded("blob")
    ])
  }

  @Test("Failing Mutation Events")
  func failingMutationEvents() async throws {
    let mutation = FailableMutation()
    let store = self.client.store(for: mutation)
    let collector = MutationStoreEventsCollector<
      FailableMutation.Arguments, FailableMutation.Value
    >()
    _ = try? await store.mutate(with: "blob", handler: collector.eventHandler())

    collector.expectEventsMatch([
      .mutatingStarted("blob"),
      .mutationResultReceived("blob", .failure(FailableMutation.SomeError())),
      .mutatingEnded("blob")
    ])
  }
}
