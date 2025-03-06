import CustomDump
import IssueReporting
import QueryCore
import Testing

// MARK: - _QueryStoreEvent

protocol QueryStoreEventProtocol: Sendable {
  func isMatch(with other: Self) -> Bool
}

// MARK: - QueryStoreEventCollector

final class _QueryStoreEventsCollector<Event: QueryStoreEventProtocol>: Sendable {
  private let events = Lock([Event]())

  func reset() {
    self.events.withLock { $0.removeAll() }
  }

  func expectEventsMatch(_ expected: [Event]) {
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

// MARK: - InfiniteQueryStoreEvent

enum InfiniteQueryStoreEvent<
  PageID: Hashable & Sendable,
  PageValue: Equatable & Sendable
>: Sendable {
  case fetchingStarted
  case fetchingEnded
  case pageFetchingStarted(PageID)
  case pageFetchingEnded(PageID)
  case pageResultReceived(PageID, Result<InfiniteQueryPage<PageID, PageValue>, any Error>)
  case resultReceived(Result<InfiniteQueryPages<PageID, PageValue>, any Error>)
}

extension InfiniteQueryStoreEvent: QueryStoreEventProtocol {
  func isMatch(with other: Self) -> Bool {
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
    case let (.pageFetchingStarted(a), .pageFetchingStarted(b)):
      return a == b
    case let (.pageFetchingEnded(a), .pageFetchingEnded(b)):
      return a == b
    case let (.pageResultReceived(a, b), .pageResultReceived(c, d)):
      let isResultMatch =
        switch (b, d) {
        case let (.success(b), .success(d)): b == d
        case (.failure, .failure): true
        default: false
        }
      return a == c && isResultMatch
    default:
      return false
    }
  }
}

typealias InfiniteQueryStoreEventsCollector<
  PageID: Hashable & Sendable,
  PageValue: Sendable & Equatable
> = _QueryStoreEventsCollector<InfiniteQueryStoreEvent<PageID, PageValue>>

extension InfiniteQueryStoreEventsCollector {
  func eventHandler<PageID: Hashable & Sendable, PageValue: Sendable & Equatable>()
    -> InfiniteQueryEventHandler<PageID, PageValue>
  where Event == InfiniteQueryStoreEvent<PageID, PageValue> {
    InfiniteQueryEventHandler(
      onFetchingStarted: { self.events.withLock { $0.append(.fetchingStarted) } },
      onPageFetchingStarted: { id in self.events.withLock { $0.append(.pageFetchingStarted(id)) } },
      onPageResultReceived: { id, result in
        self.events.withLock { $0.append(.pageResultReceived(id, result)) }
      },
      onResultReceived: { result in self.events.withLock { $0.append(.resultReceived(result)) } },
      onPageFetchingFinished: { id in self.events.withLock { $0.append(.pageFetchingEnded(id)) } },
      onFetchingFinished: { self.events.withLock { $0.append(.fetchingEnded) } }
    )
  }
}

// MARK: - QueryStoreEvent

enum QueryStoreEvent<Value: Sendable & Equatable>: Sendable {
  case fetchingStarted
  case fetchingEnded
  case resultReceived(Result<Value, any Error>)
}

extension QueryStoreEvent: QueryStoreEventProtocol {
  func isMatch(with other: Self) -> Bool {
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

typealias QueryStoreEventsCollector<Value: Equatable & Sendable> = _QueryStoreEventsCollector<
  QueryStoreEvent<Value>
>

extension QueryStoreEventsCollector {
  func eventHandler<Value: Sendable>() -> QueryEventHandler<Value>
  where Event == QueryStoreEvent<Value> {
    QueryEventHandler(
      onFetchingStarted: { self.events.withLock { $0.append(.fetchingStarted) } },
      onFetchingEnded: { self.events.withLock { $0.append(.fetchingEnded) } },
      onResultReceived: { result in self.events.withLock { $0.append(.resultReceived(result)) } }
    )
  }
}

// MARK: - Helpers

private func reportEventsDiff<Event: QueryStoreEventProtocol>(_ a: [Event], _ b: [Event]) {
  reportIssue(
    """
    Events do not match:

      \(diff(a, b) ?? "No Diff")
    """
  )
}
