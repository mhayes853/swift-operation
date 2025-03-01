import IdentifiedCollections

// MARK: - InfiniteQueryState

@dynamicMemberLookup
public struct InfiniteQueryState<PageID: Hashable & Sendable, PageValue: Sendable>: Sendable {
  public let base: QueryState<InfiniteQueryPages<PageID, PageValue>>
  public private(set) var currentPageId: PageID
  public private(set) var isLoadingNextPage = false
  public private(set) var isLoadingPreviousPage = false
  public private(set) var hasNextPage = true
  public private(set) var hasPreviousPage = true

  init(base: QueryState<InfiniteQueryPages<PageID, PageValue>>, currentPageId: PageID) {
    self.base = base
    self.currentPageId = currentPageId
  }
}

// MARK: - Dynamic Member Lookup

extension InfiniteQueryState {
  public subscript<Value>(
    dynamicMember keyPath: KeyPath<QueryState<InfiniteQueryPages<PageID, PageValue>>, Value>
  ) -> Value {
    self.base[keyPath: keyPath]
  }
}
