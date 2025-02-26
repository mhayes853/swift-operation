import CustomDump
import IssueReporting
import QueryCore
import Testing

func expectEventsMatch<Value: Sendable & Equatable>(
  _ a: @autoclosure () -> [QueryStoreSubscription.Event<Value>],
  _ b: @autoclosure () -> [QueryStoreSubscription.Event<Value>]
) {
  let a = a()
  let b = b()
  guard a.count == b.count else {
    reportEventsDiff(a, b)
    return
  }
  let isMatch = zip(a, b).allSatisfy { $0.0.isMatch(with: $0.1) }
  if !isMatch {
    reportEventsDiff(a, b)
  }
}

private func reportEventsDiff<Value: Sendable & Equatable>(
  _ a: [QueryStoreSubscription.Event<Value>],
  _ b: [QueryStoreSubscription.Event<Value>]
) {
  reportIssue(
    """
    Events do not match:

      \(diff(a, b) ?? "No Diff")
    """
  )
}

extension QueryStoreSubscription.Event where Value: Equatable {
  func isMatch(with other: QueryStoreSubscription.Event<Value>) -> Bool {
    switch (self, other) {
    case (.fetchingStarted, .fetchingStarted):
      return true
    case (.fetchingEnded, .fetchingEnded):
      return true
    case let (.resultReceived(a), .resultReceived(b)):
      switch (a, b) {
      case let (.success(a), .success(b)):
        return a == b
      case (.failure, .failure):
        return true
      default:
        return false
      }
    default:
      return false
    }
  }
}
