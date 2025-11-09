import CustomDump
import Operation
import Testing

@Suite("OperationRunner tests")
struct OperationRunnerTests {
  @Test("Runs Operation")
  func runsOperation() {
    let value = await OperationRunner(operation: $test).run()
    expectNoDifference(value, 42)
  }

  @Test("Runs Setup At Initialization")
  func runsSetupAtInitialization() {
    let runner = OperationRunner(operation: $test.retry(limit: 3))
    expectNoDifference(runner.context.operationMaxRetries, 3)
  }
}

@OperationRequest
private func test() -> Int {
  42
}
