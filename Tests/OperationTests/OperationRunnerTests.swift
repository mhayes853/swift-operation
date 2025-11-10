import CustomDump
import Operation
import Testing

@Suite("OperationRunner tests")
struct OperationRunnerTests {
  @Test("Runs Operation")
  func runsOperation() async {
    let value = await OperationRunner(operation: $testOperation).run()
    expectNoDifference(value, 42)
  }

  @Test("Runs Setup At Initialization")
  func runsSetupAtInitialization() {
    let runner = OperationRunner(operation: $testOperation.retry(limit: 3))
    expectNoDifference(runner.context.operationMaxRetries, 3)
  }
}

@OperationRequest
private func testOperation() -> Int {
  42
}
