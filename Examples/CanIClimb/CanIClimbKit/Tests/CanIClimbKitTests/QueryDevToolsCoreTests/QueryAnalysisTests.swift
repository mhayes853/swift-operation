import CanIClimbKit
import CustomDump
import Testing

@Suite("OperationAnalysis tests")
struct OperationAnalysisTests {
  struct SomeError: Error {}

  struct Something {
    var field: String
  }

  @Test(
    "Data Result Initialization",
    arguments: [
      (
        Result<Something, any Error>.success(Something(field: "blob")),
        OperationAnalysis.DataResult(
          didSucceed: true,
          dataDescription: "Something(field: \"blob\")"
        )
      ),
      (
        .failure(SomeError()),
        OperationAnalysis.DataResult(didSucceed: false, dataDescription: "SomeError()")
      )
    ]
  )
  func dataResultInitialization(
    result: Result<Something, any Error>,
    dataResult: OperationAnalysis.DataResult
  ) {
    expectNoDifference(OperationAnalysis.DataResult(result: result), dataResult)
  }
}
