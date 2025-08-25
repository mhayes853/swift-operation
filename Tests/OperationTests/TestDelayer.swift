import Foundation
import Operation

final class TestDelayer: Sendable, QueryDelayer {
  private let _delays = RecursiveLock([TimeInterval]())

  var delays: [TimeInterval] {
    self._delays.withLock { $0 }
  }

  func delay(for seconds: TimeInterval) async throws {
    self._delays.withLock { $0.append(seconds) }
  }
}
