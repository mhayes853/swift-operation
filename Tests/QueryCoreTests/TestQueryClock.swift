import Foundation
import QueryCore

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
