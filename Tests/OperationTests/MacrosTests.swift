import CustomDump
import Operation
import Testing

@Suite("Macros tests")
struct MacrosTests {
  @Test("Runs Query")
  func runsQuery() async {
    let value = await OperationRunner(operation: $testQuery).run()
    expectNoDifference(value, 42)
  }

  @Test("Runs Container Query")
  func runsContainerQuery() async {
    let container = Container(value: 42)
    let value = await OperationRunner(operation: container.$query).run()
    expectNoDifference(value, 42)
  }

  @Test("Runs Mutation")
  func runsMutation() async {
    let store = OperationStore.detached(mutation: $testMutation)
    let value = await store.mutate(with: TestArgs(arg: 42))
    expectNoDifference(value, 42)
  }

  @Test("Has Proper Path")
  func hasProperPath() async {
    var path = $testPathQuery(arg: 1, arg2: "blob").path
    expectNoDifference(path, [1, "blob"])

    path = $testPathMutation(arg: 1, arg2: "blob").path
    expectNoDifference(path, [1, "blob"])
  }
}

@QueryRequest
private func testQuery() -> Int {
  42
}

@QueryRequest(path: .custom { (arg: Int, arg2: String) in [arg, arg2] })
private func testPathQuery(arg: Int, arg2: String) -> Int {
  42
}

private struct TestArgs: Sendable {
  let arg: Int
}

@MutationRequest
private func testMutation(arguments: TestArgs) -> Int {
  arguments.arg
}

@MutationRequest(path: .custom { (arg: Int, arg2: String) in [arg, arg2] })
private func testPathMutation(arg: Int, arg2: String) -> Int {
  42
}

private struct Container: Hashable {
  let value: Int

  @QueryRequest
  func query() -> Int {
    self.value
  }
}
