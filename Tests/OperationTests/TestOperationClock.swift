import Foundation
import Operation

// MARK: - TestOperationClock

final class TestOperationClock: OperationClock, Sendable {
  private let _date: RecursiveLock<Date>

  var date: Date {
    get { self.now() }
    set { self._date.withLock { $0 = newValue } }
  }

  init(date: Date) {
    self._date = RecursiveLock(date)
  }

  func now() -> Date {
    self._date.withLock { $0 }
  }
}

// MARK: - IncrementingClock

final class IncrementingClock: OperationClock, Sendable {
  let count = Lock(0)

  func now() -> Date {
    self.count.withLock { count in
      count += 1
      return Date(timeIntervalSince1970: TimeInterval(count))
    }
  }
}
