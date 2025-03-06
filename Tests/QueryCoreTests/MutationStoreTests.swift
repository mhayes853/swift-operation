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

}
