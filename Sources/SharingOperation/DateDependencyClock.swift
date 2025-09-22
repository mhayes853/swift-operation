import Dependencies
import Foundation
import Operation

/// An `OperationClock` that uses `@Depenendency(\.date)` to compute the current date.
public struct DateDependencyClock: OperationClock {
  @Dependency(\.date) private var date

  public func now() -> Date {
    self.date.now
  }
}

extension OperationClock where Self == DateDependencyClock {
  /// An `OperationClock` that uses `@Depenendency(\.date)` to compute the current date.
  public static var dateDependency: Self {
    DateDependencyClock()
  }
}
