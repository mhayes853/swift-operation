import Clocks
import CustomDump
@testable import OperationCore
import Testing

@Suite
struct `_AsyncTimerSequence tests` {
  @Test(arguments: [(11, 20), (20, 20), (25, 30), (30, 30)])
  func `Late Iteration Schedules The Next Due Interval`(
    elapsedSeconds: Int,
    expectedDeadlineSeconds: Int
  ) async {
    let clock = TestClock()
    let start = clock.now
    let sequence = _AsyncTimerSequence(interval: Duration.seconds(10), clock: clock)
    var iterator = sequence.makeAsyncIterator()
    iterator.last = start
    await clock.advance(by: .seconds(elapsedSeconds))

    let deadline = iterator.nextDeadline(clock)

    expectNoDifference(start.duration(to: deadline), .seconds(expectedDeadlineSeconds))
  }
}
