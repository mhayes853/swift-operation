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

  @Test("Has Proper Path")
  func hasProperPath() async {
    let path = $testPathQuery(arg: 1, arg2: "blob").path
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
