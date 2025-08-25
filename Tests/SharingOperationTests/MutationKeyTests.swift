import CustomDump
import Dependencies
import OperationTestHelpers
import SharingOperation
import Testing

@Suite("MutationKey tests")
struct MutationKeyTests {
  @Test("Mutates For Value")
  func mutatesForValue() async throws {
    @SharedQuery(EmptyMutation()) var value

    expectNoDifference(value, nil)
    let expected = "blob"
    try await $value.mutate(with: expected)
    expectNoDifference(value, expected)
  }

  @Test("Mutates For Error")
  func mutatesForError() async throws {
    @SharedQuery(FailableMutation()) var value

    expectNoDifference($value.error as? FailableMutation.MutateError, nil)
    _ = try? await $value.mutate(with: "blob")
    expectNoDifference(
      $value.error as? FailableMutation.MutateError,
      FailableMutation.MutateError()
    )
  }

  @Test("Equatability Is True When Values From Separate Stores Are Equal")
  func equatability() async throws {
    @Dependency(\.defaultQueryClient) var client

    let s1 = QueryStore.detached(mutation: EmptyMutation())
    let s2 = QueryStore.detached(mutation: EmptyMutation())

    @SharedQuery(store: s1) var value1
    @SharedQuery(store: s2) var value2

    expectNoDifference(value1, value2)

    let expected = "blob"
    try await $value1.mutate(with: expected)
    withExpectedIssue { expectNoDifference(value1, value2) }

    try await $value2.mutate(with: expected)
    expectNoDifference(value1, value2)
  }
}
