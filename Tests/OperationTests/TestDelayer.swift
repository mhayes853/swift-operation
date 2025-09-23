import Foundation
import Operation

final class TestDelayer: Sendable, OperationDelayer {
  private let _delays = RecursiveLock([OperationDuration]())

  var delays: [OperationDuration] {
    self._delays.withLock { $0 }
  }

  func delay(for duration: OperationDuration) async throws {
    self._delays.withLock { $0.append(duration) }
  }
}
