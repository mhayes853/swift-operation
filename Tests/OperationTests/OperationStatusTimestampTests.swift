import CustomDump
import Foundation
import Operation
import Testing

@Suite("OperationStatus Timestamp tests")
struct OperationStatusTimestampTests {
  @Test
  func `Successful Update Wins When Error Has The Same Timestamp`() {
    struct SomeError: Error {}

    let date = Date()
    var context = OperationContext()
    context.operationClock = CustomOperationClock { date }
    var state = QueryState<Int, SomeError>(initialValue: nil)
    state.update(with: .failure(SomeError()), using: context)
    state.update(with: .success(42), using: context)

    withKnownIssue("OperationStatus cannot order updates with equal timestamps.") {
      expectNoDifference(state.status.isSuccessful, true)
    }
  }

  @Test
  func `Error Update Wins When Value Has The Same Timestamp`() {
    struct SomeError: Error {}

    let date = Date()
    var context = OperationContext()
    context.operationClock = CustomOperationClock { date }
    var state = QueryState<Int, SomeError>(initialValue: nil)
    state.update(with: .success(42), using: context)
    state.update(with: .failure(SomeError()), using: context)

    expectNoDifference(state.status.isFailure, true)
  }
}
