import Dependencies
import Foundation
import QueryCore

extension DateGenerator: QueryClock {
  public func now() -> Date {
    self.now
  }
}
