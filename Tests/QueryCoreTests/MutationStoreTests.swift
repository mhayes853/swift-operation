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

  @Test("Mutation Is Loading")
  func mutationIsLoading() async throws {
    let mutation = SleepingMutation(clock: ImmediateClock(), duration: .seconds(1))
    let store = self.client.store(for: mutation)
    mutation.didBeginSleeping = {
      expectNoDifference(store.isLoading, true)
    }
    let result = try await store.mutate(with: "blob")
    expectNoDifference(store.isLoading, false)
  }

  @Test("Mutation Throws Error")
  func mutationThrowsError() async throws {
    let mutation = FailableMutation()
    let store = self.client.store(for: mutation)
    let result = try? await store.mutate(with: "blob")
    expectNoDifference(store.error != nil, true)
    expectNoDifference(result, nil)
  }

  //@Test("Mutate Throws Error")
  //func mutateThrowsError() async throws {
  //  let mutation = EmptyMutation()
  //  let store = AnyQueryStore.detached(erasing: mutation)
  //  let mutationStore = MutationStoreFor<EmptyMutation>(casting: store)
  //  try await expectThrowsError(mutationStore!.mutate(with: mutation.arguments, in: QueryContext()))
  //}
}
