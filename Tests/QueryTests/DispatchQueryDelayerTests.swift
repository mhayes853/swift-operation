#if canImport(Dispatch)
  import CustomDump
  import Foundation
  import Query
  import XCTest

  final class DispatchQueryDelayerTests: XCTestCase {
    func testCancellation() async throws {
      let delayer: some QueryDelayer = .dispatch(queue: .global())
      let task = Task { try await delayer.delay(for: 0.2) }
      let startTime = Date()
      try await delayer.delay(for: 0.05)
      task.cancel()
      await XCTAssertThrows(try await task.value, error: CancellationError.self)
      let duration = Date().timeIntervalSince(startTime)
      expectNoDifference(duration < 0.2, true)
    }

    func testSleepsForSpecifiedDuration() async throws {
      let delayer: some QueryDelayer = .dispatch(queue: .global())
      let startTime = Date()
      try await delayer.delay(for: 0.1)
      let duration = Date().timeIntervalSince(startTime)
      expectNoDifference(duration > 0.1, true)
    }
  }
#endif
