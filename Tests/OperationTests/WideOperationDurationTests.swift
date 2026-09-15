import CustomDump
import Operation
import Testing

@Suite
struct `Wide OperationDuration tests` {
  @Test
  func `Integer Subsecond Factories Accept Wide Inputs`() {
    let value = UInt64.max

    expectNoDifference(
      OperationDuration.nanoseconds(value),
      OperationDuration(secondsComponent: 18_446_744_073, attosecondsComponent: 709_551_615_000_000_000)
    )
    expectNoDifference(
      OperationDuration.microseconds(value),
      OperationDuration(
        secondsComponent: 18_446_744_073_709,
        attosecondsComponent: 551_615_000_000_000_000
      )
    )
    expectNoDifference(
      OperationDuration.milliseconds(value),
      OperationDuration(
        secondsComponent: 18_446_744_073_709_551,
        attosecondsComponent: 615_000_000_000_000_000
      )
    )
  }

  @Test
  func `Integer Subsecond Factories Accept Narrow Inputs`() {
    expectNoDifference(OperationDuration.nanoseconds(Int8.max), .nanoseconds(127))
    expectNoDifference(OperationDuration.microseconds(UInt8.max), .microseconds(255))
    expectNoDifference(OperationDuration.milliseconds(Int8.min), .milliseconds(-128))
  }
}
