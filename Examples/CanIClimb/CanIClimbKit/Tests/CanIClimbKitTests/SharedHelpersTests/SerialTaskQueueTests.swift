import CanIClimbKit
import CustomDump
import Synchronization
import XCTest

final class SerialTaskQueueTests: XCTestCase {
  func testAlwaysRunsSerially() async throws {
    let queue = SerialTaskQueue(priority: .high)

    let time = try await ContinuousClock().measure {
      let t1 = Task { @Sendable in
        try await queue.run { try await Task.sleep(for: .seconds(0.1)) }
      }
      let t2 = Task { @Sendable in
        try await queue.run { try await Task.sleep(for: .seconds(0.1)) }
      }
      let t3 = Task { @Sendable in
        try await queue.run { try await Task.sleep(for: .seconds(0.1)) }
      }
      _ = try await (t1.value, t2.value, t3.value)
    }

    expectNoDifference(time >= .seconds(0.3), true)
  }

  func testHandlesCancellationProperly() async throws {
    let queue = SerialTaskQueue(priority: .high)

    let task = Task {
      try await queue.run { try await Task.never() }
    }
    task.cancel()
    
    let expectation = self.expectation(description: "runs")
    Task { try await queue.run { expectation.fulfill() } }
    await self.fulfillment(of: [expectation])
  }
}
