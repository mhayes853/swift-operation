import CustomDump
import IssueReporting
import Operation
import Testing

// MARK: - _OperationStoreEvent

package protocol OperationStoreEventProtocol: Sendable {
  func isMatch(with other: Self) -> Bool
}

// MARK: - OperationStoreEventCollector

package final class _OperationStoreEventsCollector<Event: OperationStoreEventProtocol>: Sendable {
  private let events = RecursiveLock([Event]())

  package init() {}

  package func reset() {
    self.events.withLock { $0.removeAll() }
  }

  package func expectEventsMatch(_ expected: [Event]) {
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

// MARK: - MutationStoreEvent

package enum MutationStoreEvent<Arguments: Equatable & Sendable, Value: Equatable & Sendable>:
  Sendable
{
  case mutatingStarted(Arguments)
  case mutatingEnded(Arguments)
  case mutationResultReceived(Arguments, Result<Value, any Error>)
  case stateChanged
}

extension MutationStoreEvent: OperationStoreEventProtocol {
  package func isMatch(with other: Self) -> Bool {
    switch (self, other) {
    case (.mutatingStarted(let a), .mutatingStarted(let b)):
      return a == b
    case (.mutatingEnded(let a), .mutatingEnded(let b)):
      return a == b
    case (.mutationResultReceived(let a, let b), .mutationResultReceived(let c, let d)):
      let isResultMatch =
        switch (b, d) {
        case (.success(let b), .success(let d)): b == d
        case (.failure, .failure): true
        default: false
        }
      return a == c && isResultMatch
    case (.stateChanged, .stateChanged):
      return true
    default:
      return false
    }
  }
}

package typealias MutationStoreEventsCollector<
  Arguments: Equatable & Sendable,
  Value: Equatable & Sendable
> = _OperationStoreEventsCollector<MutationStoreEvent<Arguments, Value>>

extension MutationStoreEventsCollector {
  package func eventHandler<Arguments: Equatable & Sendable, Value: Equatable & Sendable>()
    -> MutationEventHandler<Arguments, Value>
  where Event == MutationStoreEvent<Arguments, Value> {
    MutationEventHandler(
      onStateChanged: { _, _ in self.events.withLock { $0.append(.stateChanged) } },
      onMutatingStarted: { args, _ in self.events.withLock { $0.append(.mutatingStarted(args)) } },
      onMutationResultReceived: { args, result, _ in
        self.events.withLock { $0.append(.mutationResultReceived(args, result)) }
      },
      onMutatingEnded: { args, _ in self.events.withLock { $0.append(.mutatingEnded(args)) } }
    )
  }
}

// MARK: - InfiniteOperationStoreEvent

package enum InfiniteOperationStoreEvent<
  PageID: Hashable & Sendable,
  PageValue: Equatable & Sendable
>: Sendable {
  case fetchingStarted
  case fetchingEnded
  case pageFetchingStarted(PageID)
  case pageFetchingEnded(PageID)
  case pageResultReceived(PageID, Result<InfiniteQueryPage<PageID, PageValue>, any Error>)
  case resultReceived(Result<InfiniteQueryPages<PageID, PageValue>, any Error>)
  case stateChanged
}

extension InfiniteOperationStoreEvent: OperationStoreEventProtocol {
  package func isMatch(with other: Self) -> Bool {
    switch (self, other) {
    case (.fetchingStarted, .fetchingStarted):
      return true
    case (.fetchingEnded, .fetchingEnded):
      return true
    case (.resultReceived(let a), .resultReceived(let b)):
      switch (a, b) {
      case (.success(let a), .success(let b)):
        return a == b
      case (.failure, .failure):
        return true
      default:
        return false
      }
    case (.pageFetchingStarted(let a), .pageFetchingStarted(let b)):
      return a == b
    case (.pageFetchingEnded(let a), .pageFetchingEnded(let b)):
      return a == b
    case (.pageResultReceived(let a, let b), .pageResultReceived(let c, let d)):
      let isResultMatch =
        switch (b, d) {
        case (.success(let b), .success(let d)): b == d
        case (.failure, .failure): true
        default: false
        }
      return a == c && isResultMatch
    case (.stateChanged, .stateChanged):
      return true
    default:
      return false
    }
  }
}

package typealias InfiniteOperationStoreEventsCollector<
  PageID: Hashable & Sendable,
  PageValue: Sendable & Equatable
> = _OperationStoreEventsCollector<InfiniteOperationStoreEvent<PageID, PageValue>>

extension InfiniteOperationStoreEventsCollector {
  package func eventHandler<PageID: Hashable & Sendable, PageValue: Sendable & Equatable>()
    -> InfiniteQueryEventHandler<PageID, PageValue>
  where Event == InfiniteOperationStoreEvent<PageID, PageValue> {
    InfiniteQueryEventHandler(
      onStateChanged: { _, _ in self.events.withLock { $0.append(.stateChanged) } },
      onFetchingStarted: { _ in self.events.withLock { $0.append(.fetchingStarted) } },
      onPageFetchingStarted: { id, _ in self.events.withLock { $0.append(.pageFetchingStarted(id)) }
      },
      onPageResultReceived: { id, result, _ in
        self.events.withLock { $0.append(.pageResultReceived(id, result)) }
      },
      onResultReceived: { result, _ in self.events.withLock { $0.append(.resultReceived(result)) }
      },
      onPageFetchingEnded: { id, _ in self.events.withLock { $0.append(.pageFetchingEnded(id)) }
      },
      onFetchingEnded: { _ in self.events.withLock { $0.append(.fetchingEnded) } }
    )
  }
}

// MARK: - OperationStoreEvent

package enum OperationStoreEvent<State: OperationState>: Sendable
where State.OperationValue: Equatable {
  case fetchingStarted
  case fetchingEnded
  case stateChanged
  case resultReceived(Result<State.OperationValue, any Error>)
}

extension OperationStoreEvent: OperationStoreEventProtocol {
  package func isMatch(with other: Self) -> Bool {
    switch (self, other) {
    case (.fetchingStarted, .fetchingStarted):
      return true
    case (.fetchingEnded, .fetchingEnded):
      return true
    case (.resultReceived(let a), .resultReceived(let b)):
      switch (a, b) {
      case (.success(let a), .success(let b)):
        return a == b
      case (.failure, .failure):
        return true
      default:
        return false
      }
    case (.stateChanged, .stateChanged):
      return true
    default:
      return false
    }
  }
}

package typealias OperationStoreEventsCollector<
  State: OperationState
> = _OperationStoreEventsCollector<OperationStoreEvent<State>> where State.OperationValue: Equatable

extension OperationStoreEventsCollector {
  package func eventHandler<State>() -> QueryEventHandler<State>
  where Event == OperationStoreEvent<State> {
    QueryEventHandler(
      onStateChanged: { _, _ in self.events.withLock { $0.append(.stateChanged) } },
      onFetchingStarted: { _ in self.events.withLock { $0.append(.fetchingStarted) } },
      onFetchingEnded: { _ in self.events.withLock { $0.append(.fetchingEnded) } },
      onResultReceived: { result, _ in self.events.withLock { $0.append(.resultReceived(result)) } }
    )
  }
}

// MARK: - Helpers

private func reportEventsDiff<Event: OperationStoreEventProtocol>(_ a: [Event], _ b: [Event]) {
  reportIssue(
    """
    Events do not match:

      \(diff(a, b) ?? "No Diff")
    """
  )
}
