import CustomDump
import IssueReporting
import QueryCore
import Testing

// MARK: - QueryStoreEventCollector

final class QueryStoreEventsCollector<Value: Equatable & Sendable>: Sendable {
  private let events = Lock([QueryStoreEvent<Value>]())

  var eventHandler: QueryEventHandler<Value> {
    QueryEventHandler(
      onFetchingStarted: { self.events.withLock { $0.append(.fetchingStarted) } },
      onFetchingEnded: { self.events.withLock { $0.append(.fetchingEnded) } },
      onResultReceived: { result in self.events.withLock { $0.append(.resultReceived(result)) } }
    )
  }

  func reset() {
    self.events.withLock { $0.removeAll() }
  }

  func expectEventsMatch(_ expected: [QueryStoreEvent<Value>]) {
    let events = self.events.withLock { $0 }
    guard events.count == expected.count else {
      reportEventsDiff(events, expected)
      return
    }
    let isMatch = zip(events, expected).allSatisfy { $0.0.isMatch(with: $0.1) }
    if !isMatch {
      reportEventsDiff(events, expected)
    }
  }
}

// MARK: - QueryStoreEvent

enum QueryStoreEvent<Value: Sendable>: Sendable {
  case fetchingStarted
  case fetchingEnded
  case resultReceived(Result<Value, any Error>)
}

// MARK: - Helpers

private func reportEventsDiff<Value: Sendable & Equatable>(
  _ a: [QueryStoreEvent<Value>],
  _ b: [QueryStoreEvent<Value>]
) {
  reportIssue(
    """
    Events do not match:

      \(diff(a, b) ?? "No Diff")
    """
  )
}

extension QueryStoreEvent where Value: Equatable {
  fileprivate func isMatch(with other: Self) -> Bool {
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
