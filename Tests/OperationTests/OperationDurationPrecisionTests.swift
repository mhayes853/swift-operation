import CustomDump
import Operation
import Testing

@Suite
struct `OperationDuration Precision tests` {
  @Test
  func `Multiplication By One Preserves Precision`() {
    let duration = OperationDuration(secondsComponent: 1_000_000_000, attosecondsComponent: 1)

    withKnownIssue("Integer duration multiplication converts components through Double.") {
      expectNoDifference(duration * 1, duration)
    }
  }

  @Test
  func `Division By One Preserves Precision`() {
    let duration = OperationDuration(secondsComponent: 1_000_000_000, attosecondsComponent: 1)

    withKnownIssue("Integer duration division converts components through Double.") {
      expectNoDifference(duration / 1, duration)
    }
  }
}
