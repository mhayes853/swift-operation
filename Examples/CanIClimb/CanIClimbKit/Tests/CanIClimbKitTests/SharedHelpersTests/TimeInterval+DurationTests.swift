import CanIClimbKit
import CustomDump
import Foundation
import Testing

@Suite("TimeInterval+Duration tests")
struct TimeIntervalDurationTests {
  @Test("Duration to TimeInterval")
  func convert() async throws {
    let duration = Duration.milliseconds(3500)
    let timeInterval = TimeInterval(duration: duration)
    expectNoDifference(timeInterval, 3.5)
  }
}
