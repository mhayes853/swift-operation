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

package enum MutationStoreEvent<State: _MutationStateProtocol>: Sendable
where State.Arguments: Equatable, State.StatusValue: Equatable {
  case mutatingStarted(State.Arguments)
  case mutatingEnded(State.Arguments)
  case mutationResultReceived(State.Arguments, Result<State.Value, State.Failure>)
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
  State: _MutationStateProtocol
> = _OperationStoreEventsCollector<MutationStoreEvent<State>>
where State.Arguments: Equatable, State.StatusValue: Equatable

extension MutationStoreEventsCollector {
  package func eventHandler<State: _MutationStateProtocol>()
    -> MutationEventHandler<State>
  where Event == MutationStoreEvent<State> {
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

package enum InfiniteOperationStoreEvent<State: _InfiniteQueryStateProtocol>: Sendable
where State.PageID: Equatable, State.PageValue: Equatable {
  case fetchingStarted
  case fetchingEnded
  case pageFetchingStarted(State.PageID)
  case pageFetchingEnded(State.PageID)
  case pageResultReceived(
    State.PageID,
    Result<InfiniteQueryPage<State.PageID, State.PageValue>, State.Failure>
  )
  case resultReceived(Result<InfiniteQueryPages<State.PageID, State.PageValue>, State.Failure>)
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
  State: _InfiniteQueryStateProtocol
> = _OperationStoreEventsCollector<InfiniteOperationStoreEvent<State>>
where State.PageID: Equatable, State.PageValue: Equatable

extension InfiniteOperationStoreEventsCollector {
  package func eventHandler<State: _InfiniteQueryStateProtocol>()
    -> InfiniteQueryEventHandler<State>
  where Event == InfiniteOperationStoreEvent<State> {
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
      onResultReceived: { result, _ in
        self.events.withLock { $0.append(.resultReceived(result.mapError { $0 })) }
      }
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
