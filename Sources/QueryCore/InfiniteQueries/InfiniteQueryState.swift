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
  public var currentValue: StateValue {
    get { self.base.currentValue }
    set { self.base.currentValue = newValue }
  }

  public var initialValue: StateValue {
    get { self.base.initialValue }
    set { self.base.initialValue = newValue }
  }

  public var valueUpdateCount: Int {
    get { self.base.valueUpdateCount }
    set { self.base.valueUpdateCount = newValue }
  }

  public var valueLastUpdatedAt: Date? {
    get { self.base.valueLastUpdatedAt }
    set { self.base.valueLastUpdatedAt = newValue }
  }

  public var isLoading: Bool {
    get { self.base.isLoading }
    set { self.base.isLoading = newValue }
  }

  public var error: (any Error)? {
    get { self.base.error }
    set { self.base.error = newValue }
  }

  public var errorUpdateCount: Int {
    get { self.base.errorUpdateCount }
    set { self.base.errorUpdateCount = newValue }
  }

  public var errorLastUpdatedAt: Date? {
    get { self.base.errorLastUpdatedAt }
    set { self.base.errorLastUpdatedAt = newValue }
  }

  public var fetchTask: Task<any Sendable, any Error>? {
    get { self.base.fetchTask }
    set { self.base.fetchTask = newValue }
  }

  public init(initialValue: StateValue) {
    self.base = QueryState(initialValue: initialValue)
    self.currentPageId = InfiniteQueryLocal.currentPageId?.base as! PageID
  }

  public func casted<NewValue: Sendable, NewQueryValue: Sendable>(
    to newValue: NewValue.Type,
    newQueryValue: NewQueryValue.Type
  ) -> (any QueryStateProtocol)? {
    self.base.casted(to: newValue, newQueryValue: newQueryValue)
  }
}

enum InfiniteQueryLocal {
  @TaskLocal static var currentPageId: AnyHashableSendable?
}
