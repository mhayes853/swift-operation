import ConcurrencyExtras
import Foundation
import IdentifiedCollections

public protocol _InfiniteQueryStateProtocol: QueryStateProtocol {
  associatedtype PageID: Hashable & Sendable
  associatedtype PageValue: Sendable
  associatedtype StateValue = InfiniteQueryPages<PageID, PageValue>
  associatedtype QueryValue = StateValue
}

// MARK: - InfiniteQueryState

public struct InfiniteQueryState<PageID: Hashable & Sendable, PageValue: Sendable> {
  public var base:
    QueryState<InfiniteQueryPages<PageID, PageValue>, InfiniteQueryPages<PageID, PageValue>>
  public private(set) var currentPageId: PageID
  public private(set) var isLoadingNextPage = false
  public private(set) var isLoadingPreviousPage = false
  public private(set) var hasNextPage = true
  public private(set) var hasPreviousPage = true

  init(initialValue: StateValue, currentPageId: PageID) {
    self.base = QueryState(initialValue: initialValue)
    self.currentPageId = currentPageId
  }
}

extension InfiniteQueryState: _InfiniteQueryStateProtocol {
  public var currentValue: StateValue { self.base.currentValue }

  public var initialValue: StateValue { self.base.initialValue }

  public var valueUpdateCount: Int { self.base.valueUpdateCount }

  public var valueLastUpdatedAt: Date? { self.base.valueLastUpdatedAt }

  public var isLoading: Bool { self.base.isLoading }

  public var error: (any Error)? { self.base.error }

  public var errorUpdateCount: Int { self.base.errorUpdateCount }

  public var errorLastUpdatedAt: Date? { self.base.errorLastUpdatedAt }

  public var fetchTask: Task<any Sendable, any Error>? { self.base.fetchTask }

  public mutating func startFetchTask(
    in context: QueryContext,
    for fn: @escaping @Sendable () async throws -> any Sendable
  ) -> Task<any Sendable, any Error> {
    self.base.startFetchTask(in: context, for: fn)
  }

  public mutating func endFetchTask(in context: QueryContext, with value: QueryValue) {
    self.base.endFetchTask(in: context, with: value)
  }

  public mutating func finishFetchTask(in context: QueryContext, with error: any Error) {
    self.base.finishFetchTask(in: context, with: error)
  }
}
