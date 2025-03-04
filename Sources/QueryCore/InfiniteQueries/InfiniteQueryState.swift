import ConcurrencyExtras
import Foundation
import IdentifiedCollections

// MARK: - InfiniteQueryState

public struct InfiniteQueryState<PageID: Hashable & Sendable, PageValue: Sendable> {
  public var base:
    QueryState<InfiniteQueryPages<PageID, PageValue>, InfiniteQueryPages<PageID, PageValue>>
  public let initialPageId: PageID
  public private(set) var isLoadingNextPage = false
  public private(set) var isLoadingPreviousPage = false
  public private(set) var hasNextPage = true
  public private(set) var hasPreviousPage = true

  init(initialValue: StateValue, initialPageId: PageID) {
    self.base = QueryState(initialValue: initialValue)
    self.initialPageId = initialPageId
  }
}

// MARK: - InfiniteQueryStateProtocol Conformance

extension InfiniteQueryState: QueryStateProtocol {
  public typealias StateValue = InfiniteQueryPages<PageID, PageValue>
  public typealias QueryValue = StateValue

  public var currentValue: StateValue { self.base.currentValue }

  public var initialValue: StateValue { self.base.initialValue }

  public var valueUpdateCount: Int { self.base.valueUpdateCount }

  public var valueLastUpdatedAt: Date? { self.base.valueLastUpdatedAt }

  public var isLoading: Bool { self.base.isLoading }

  public var error: (any Error)? { self.base.error }

  public var errorUpdateCount: Int { self.base.errorUpdateCount }

  public var errorLastUpdatedAt: Date? { self.base.errorLastUpdatedAt }

  public var fetchTask: Task<any Sendable, any Error>? { self.base.fetchTask }

  // TODO: - Infinite Query Logic

  public mutating func startFetchTask(
    in context: QueryContext,
    for fn: @escaping @Sendable () async throws -> any Sendable
  ) -> Task<any Sendable, any Error> {
    self.base.startFetchTask(in: context, for: fn)
  }

  public mutating func endFetchTask(
    in context: QueryContext,
    with result: Result<QueryValue, Error>
  ) {
    self.base.endFetchTask(in: context, with: result)
  }
}
