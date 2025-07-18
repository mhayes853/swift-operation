import CanIClimbKit
import CustomDump
import Testing

@Suite("QueryAnalysis tests")
struct QueryAnalysisTests {
  struct SomeError: Error {}

  struct Something {
    var field: String
  }

  @Test(
    "Data Result Initialization",
    arguments: [
      (
        Result<Something, any Error>.success(Something(field: "blob")),
        QueryAnalysis.DataResult(didSucceed: true, dataDescription: "Something(field: \"blob\")")
      ),
      (
        .failure(SomeError()),
        QueryAnalysis.DataResult(didSucceed: false, dataDescription: "SomeError()")
      )
    ]
  )
  func dataResultInitialization(
    result: Result<Something, any Error>,
    dataResult: QueryAnalysis.DataResult
  ) {
    expectNoDifference(QueryAnalysis.DataResult(result: result), dataResult)
  }
}
