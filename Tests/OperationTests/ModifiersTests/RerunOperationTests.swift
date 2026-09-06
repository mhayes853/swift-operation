import CustomDump
import Foundation
import Operation
import Testing

@Suite("RerunOperation tests")
struct RerunOperationTests {
  @Test("Runs Once When The First Value Is Satisfactory")
  func runsOnceWhenTheFirstValueIsSatisfactory() async {
    let counter = RunCounter()
    let delayer = AdvancingDelayer()
    let value = await #run(
      counter.operation { _ in true }
        .rerun(while: { !$0 }, for: .seconds(30))
        .delayer(delayer)
        .clock(delayer.clock)
    )
    expectNoDifference(value, true)
    expectNoDifference(counter.count, 1)
    expectNoDifference(delayer.delays, [])
  }

  @Test("Reruns Until The Value Is Satisfactory")
  func rerunsUntilTheValueIsSatisfactory() async {
    let counter = RunCounter()
    let delayer = AdvancingDelayer()
    let value = await #run(
      counter.operation { $0 >= 3 }
        .rerun(while: { !$0 }, for: .seconds(30))
        .backoff(.constant(.milliseconds(100)))
        .delayer(delayer)
        .clock(delayer.clock)
    )
    expectNoDifference(value, true)
    expectNoDifference(counter.count, 3)
    expectNoDifference(delayer.delays, [.milliseconds(100), .milliseconds(100)])
  }

  @Test("Returns The Last Value When The Duration Elapses")
  func returnsTheLastValueWhenTheDurationElapses() async {
    let counter = RunCounter()
    let delayer = AdvancingDelayer()
    let value = await #run(
      counter.operation { _ in false }
        .rerun(while: { !$0 }, for: .seconds(1))
        .backoff(.constant(.milliseconds(400)))
        .delayer(delayer)
        .clock(delayer.clock)
    )
    expectNoDifference(value, false)
    expectNoDifference(counter.count, 4)
  }

  @Test("Clamps The Final Delay To What Remains Of The Duration")
  func clampsTheFinalDelayToWhatRemainsOfTheDuration() async {
    let delayer = AdvancingDelayer()
    _ = await #run(
      RunCounter().operation { _ in false }
        .rerun(while: { !$0 }, for: .seconds(1))
        .backoff(.constant(.milliseconds(400)))
        .delayer(delayer)
        .clock(delayer.clock)
    )
    // The final delay is the remainder of the second, not another full 400ms. It is not asserted
    // exactly: `OperationClock` measures in `Date`, whose Double mantissa only resolves about
    // 100ns at real world timestamps, so the remainder carries a little noise.
    expectNoDifference(delayer.delays.count, 3)
    expectNoDifference(Array(delayer.delays.prefix(2)), [.milliseconds(400), .milliseconds(400)])
    expectNoDifference(delayer.delays[2] < .milliseconds(400), true)
    expectNoDifference(delayer.delays[2] > .milliseconds(199), true)
  }

  @Test("Delays By An Increasing Backoff For Each Rerun")
  func delaysByAnIncreasingBackoffForEachRerun() async {
    let counter = RunCounter()
    let delayer = AdvancingDelayer()
    _ = await #run(
      counter.operation { $0 >= 4 }
        .rerun(while: { !$0 }, for: .seconds(30))
        .backoff(.exponential(.milliseconds(100)))
        .delayer(delayer)
        .clock(delayer.clock)
    )
    expectNoDifference(
      delayer.delays,
      [.milliseconds(100), .milliseconds(200), .milliseconds(400)]
    )
  }

  @Test("Runs Once When The Duration Is Zero")
  func runsOnceWhenTheDurationIsZero() async {
    let counter = RunCounter()
    let delayer = AdvancingDelayer()
    let value = await #run(
      counter.operation { _ in false }
        .rerun(while: { !$0 }, for: .zero)
        .delayer(delayer)
        .clock(delayer.clock)
    )
    expectNoDifference(value, false)
    expectNoDifference(counter.count, 1)
    expectNoDifference(delayer.delays, [])
  }

  @Test("Does Not Rerun An Operation That Throws")
  func doesNotRerunAnOperationThatThrows() async {
    let counter = RunCounter()
    let delayer = AdvancingDelayer()
    let operation = InlineOperation<Bool, any Error> { _ in
      counter.increment()
      throw SomeError()
    }
    await #expect(throws: SomeError.self) {
      try await #run(
        operation.rerun(while: { !$0 }, for: .seconds(30))
          .delayer(delayer)
          .clock(delayer.clock)
      )
    }
    expectNoDifference(counter.count, 1)
    expectNoDifference(delayer.delays, [])
  }

  @Test("Stops Rerunning When The Task Is Cancelled")
  func stopsRerunningWhenTheTaskIsCancelled() async {
    let counter = RunCounter()
    let task = Task {
      await #run(
        counter.operation { _ in false }
          .rerun(while: { !$0 }, for: .seconds(30))
          .backoff(.noBackoff)
          .delayer(.noDelay)
      )
    }
    task.cancel()
    let value = await task.value
    expectNoDifference(value, false)
    expectNoDifference(counter.count < 3, true)
  }
}

// MARK: - Helpers

private struct SomeError: Equatable, Error {}

/// Counts runs, and reports whether the run it just performed is satisfactory.
private final class RunCounter: Sendable {
  private let _count = RecursiveLock(0)

  var count: Int {
    self._count.withLock { $0 }
  }

  func increment() {
    self._count.withLock { $0 += 1 }
  }

  func operation(
    _ isSatisfactory: @escaping @Sendable (Int) -> Bool
  ) -> InlineOperation<Bool, Never> {
    InlineOperation("counted") { _ in
      isSatisfactory(
        self._count.withLock { count in
          count += 1
          return count
        }
      )
    }
  }
}

/// A delayer that advances a clock by the delay rather than sleeping, so that a deadline can be
/// reached deterministically.
private final class AdvancingDelayer: OperationDelayer, Sendable {
  let clock = TestOperationClock(date: Date(timeIntervalSince1970: 0))
  private let _delays = RecursiveLock([OperationDuration]())

  var delays: [OperationDuration] {
    self._delays.withLock { $0 }
  }

  func delay(for duration: OperationDuration) async throws {
    self._delays.withLock { $0.append(duration) }
    let (seconds, attoseconds) = duration.components
    self.clock.date = self.clock.date.addingTimeInterval(
      TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    )
  }
}
