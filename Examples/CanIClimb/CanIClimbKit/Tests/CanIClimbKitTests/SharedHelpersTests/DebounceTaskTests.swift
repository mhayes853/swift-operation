import CanIClimbKit
import Clocks
import CustomDump
import XCTest

final class DebounceTaskTests: XCTestCase {
  private let clock = TestClock()

  func testScheduleDoesNotBeginRunningWorkImmediately() async {
    let expectation = self.expectation(description: "runs")
    expectation.isInverted = true

    let task = DebounceTask(clock: self.clock, duration: .seconds(1)) {
      expectation.fulfill()
    }
    task.schedule()
    await self.fulfillment(of: [expectation], timeout: 0.1)
  }

  func testScheduleRunsAfterSpecifiedDuration() async {
    let expectation = self.expectation(description: "runs")
    let task = DebounceTask(clock: self.clock, duration: .seconds(1)) {
      expectation.fulfill()
    }
    task.schedule()
    await self.clock.advance(by: .seconds(1))
    await self.fulfillment(of: [expectation], timeout: 0.1)
  }

  func testResetsWaitWhenRescheduling() async {
    let expectation = self.expectation(description: "runs")
    expectation.isInverted = true

    let task = DebounceTask(clock: self.clock, duration: .seconds(1)) {
      expectation.fulfill()
    }
    task.schedule()
    await self.clock.advance(by: .seconds(0.5))

    task.schedule()
    await self.clock.advance(by: .seconds(0.5))

    await self.fulfillment(of: [expectation], timeout: 0.1)
  }

  func testCancelStopsScheduledWork() async {
    let expectation = self.expectation(description: "runs")
    expectation.isInverted = true

    let task = DebounceTask(clock: self.clock, duration: .seconds(1)) {
      expectation.fulfill()
    }
    task.schedule()
    task.cancel()
    await self.clock.advance(by: .seconds(1))

    await self.fulfillment(of: [expectation], timeout: 0.1)
  }

  func testCancelsWhenDeinitialized() async {
    let expectation = self.expectation(description: "runs")
    expectation.isInverted = true

    do {
      let task = DebounceTask(clock: self.clock, duration: .seconds(1)) {
        expectation.fulfill()
      }
      task.schedule()
    }
    await self.clock.advance(by: .seconds(1))

    await self.fulfillment(of: [expectation], timeout: 0.1)
  }
}
