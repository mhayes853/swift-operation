import CustomDump
import Foundation
import QueryCore
import Testing

@Suite("DispatchQueryDelayer tests")
struct DispatchQueryDelayerTests {
  @Test("Cancellation")
  func cancellation() async throws {
    let delayer: some QueryDelayer = .dispatch(queue: .global())
    let task = Task { try await delayer.delay(for: 0.2) }
    let startTime = Date()
    try await delayer.delay(for: 0.1)
    task.cancel()
    await #expect(throws: CancellationError.self) {
      try await task.value
    }
    let duration = Date().timeIntervalSince(startTime)
    expectNoDifference(duration < 0.2, true)
  }

  @Test("Sleeps For Specified Duration")
  func sleepsForSpecifiedDuration() async throws {
    let delayer: some QueryDelayer = .dispatch(queue: .global())
    let startTime = Date()
    try await delayer.delay(for: 0.1)
    let duration = Date().timeIntervalSince(startTime)
    expectNoDifference(duration > 0.1, true)
  }
}
