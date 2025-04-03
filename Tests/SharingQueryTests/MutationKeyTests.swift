import CustomDump
import Dependencies
import SharingQuery
import Testing
import _TestQueries

@Suite("MutationKey tests")
struct MutationKeyTests {
  @Test("Mutates For Value")
  func mutatesForValue() async throws {
    @Shared(.mutation(EmptyMutation())) var value

    expectNoDifference(value.currentValue, nil)
    let expected = "blob"
    try await value.mutate(with: expected)
    expectNoDifference(value.currentValue, expected)
  }

  @Test("Mutates For Error")
  func mutatesForError() async throws {
    @Shared(.mutation(FailableMutation())) var value

    expectNoDifference($value.loadError as? FailableMutation.MutateError, nil)
    _ = try? await value.mutate(with: "blob")
    expectNoDifference(
      $value.loadError as? FailableMutation.MutateError,
      FailableMutation.MutateError()
    )
  }

  @Test("Set Value, Updates Value In Store")
  func setValueUpdatesValueInStore() async throws {
    @Dependency(\.queryClient) var client

    @Shared(.mutation(EmptyMutation())) var value

    let expected = "blob"
    $value.withLock { $0.currentValue = expected }
    expectNoDifference(value.currentValue, expected)
    expectNoDifference(client.store(for: EmptyMutation()).currentValue, value.currentValue)
  }

  @Test("Shares State With QueryStateKey")
  func sharesStateWithQueryStateKey() async throws {
    @Dependency(\.queryClient) var client

    @Shared(.mutation(EmptyMutation())) var value
    @SharedReader(.mutationState(EmptyMutation())) var state

    let expected = "blob"
    $value.withLock { $0.currentValue = expected }
    expectNoDifference(value.currentValue, expected)
    expectNoDifference(state.currentValue, expected)
  }

  @Test("Equatability Is True When Values From Separate Stores Are Equal")
  func equatability() async throws {
    @Dependency(\.queryClient) var client

    let s1 = QueryStore.detached(mutation: EmptyMutation())
    let s2 = QueryStore.detached(mutation: EmptyMutation())

    @Shared(.mutation(store: s1)) var value1
    @Shared(.mutation(store: s2)) var value2

    expectNoDifference(value1, value2)

    let expected = "blob"
    try await value1.mutate(with: expected)
    withExpectedIssue { expectNoDifference(value1, value2) }

    try await value2.mutate(with: expected)
    expectNoDifference(value1, value2)
  }

  @Test("Makes Separate Subscribers When Using MutationKey And QueryStateKey In Conjunction")
  func makesSeparateSubscribersWhenUsingMutationKeyAndQueryStateKeyInConjunction() async throws {
    @Dependency(\.queryClient) var client

    let mutation = EmptyMutation()
    @Shared(.mutation(mutation)) var value
    @SharedReader(.mutationState(mutation)) var state

    let store = client.store(for: mutation)
    expectNoDifference(store.subscriberCount, 2)
  }

  @Test("Makes Separate Subscribers When Using MutationKeys With The Same Mutation")
  func makesSeparateSubscribersWhenUsingMutationKeysWithTheSameMutation() async throws {
    @Dependency(\.queryClient) var client

    let mutation = EmptyMutation()
    @Shared(.mutation(mutation)) var value1
    @Shared(.mutation(mutation)) var value2

    let store = client.store(for: mutation)
    expectNoDifference(store.subscriberCount, 2)
  }
}
