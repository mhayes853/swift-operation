import Foundation
import Operation

// MARK: - TestQueryClock

final class TestQueryClock: QueryClock {
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

final class IncrementingClock: QueryClock {
  let count = Lock(0)

  func now() -> Date {
    self.count.withLock { count in
      count += 1
      return Date(timeIntervalSince1970: TimeInterval(count))
    }
  }
}
