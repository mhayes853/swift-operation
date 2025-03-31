import Dependencies
import Foundation
import Query

extension DateGenerator: QueryClock {
  public func now() -> Date {
    self.now
  }
}
