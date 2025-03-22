import ConcurrencyExtras
import Foundation
import IdentifiedCollections

// MARK: - InfiniteQueryState

public struct InfiniteQueryState<PageID: Hashable & Sendable, PageValue: Sendable> {
  public let initialPageId: PageID
  public private(set) var currentValue: StateValue
  public let initialValue: StateValue
  public private(set) var valueUpdateCount = 0
  public private(set) var valueLastUpdatedAt: Date?

  public private(set) var error: (any Error)?
  public private(set) var errorUpdateCount = 0
  public private(set) var errorLastUpdatedAt: Date?

  public private(set) var hasNextPage = true
  public private(set) var hasPreviousPage = true
  public private(set) var nextPageId: PageID?
  public private(set) var previousPageId: PageID?

  public private(set) var fetchAllTasks = IdentifiedArrayOf<QueryTask<QueryValue>>()
  public private(set) var fetchInitialTasks = IdentifiedArrayOf<QueryTask<QueryValue>>()
  public private(set) var fetchNextTasks = IdentifiedArrayOf<QueryTask<QueryValue>>()
  public private(set) var fetchPreviousTasks = IdentifiedArrayOf<QueryTask<QueryValue>>()

  private var requests = [QueryTaskIdentifier: InfiniteQueryPagingRequest<PageID>]()

  init(initialValue: StateValue, initialPageId: PageID) {
    self.currentValue = initialValue
    self.initialValue = initialValue
    self.initialPageId = initialPageId
  }
}

// MARK: - Is Loading

extension InfiniteQueryState {
  public var isLoadingNextPage: Bool {
    !self.fetchNextTasks.isEmpty
  }

  public var isLoadingPreviousPage: Bool {
    !self.fetchPreviousTasks.isEmpty
  }

  public var isLoadingAllPages: Bool {
    !self.fetchAllTasks.isEmpty
  }

  public var isLoadingInitialPage: Bool {
    !self.fetchInitialTasks.isEmpty
  }
}

// MARK: - QueryStateProtocol Conformance

extension InfiniteQueryState: QueryStateProtocol {
  public typealias StateValue = InfiniteQueryPages<PageID, PageValue>
  public typealias QueryValue = InfiniteQueryValue<PageID, PageValue>
  public typealias StatusValue = StateValue

  public var isLoading: Bool {
    self.isLoadingAllPages || self.isLoadingNextPage || self.isLoadingPreviousPage
      || self.isLoadingInitialPage
  }

  public mutating func scheduleFetchTask(
    _ task: inout QueryTask<InfiniteQueryValue<PageID, PageValue>>
  ) {
    switch self.request(in: task.configuration.context) {
    case .allPages:
      task.schedule(after: self.fetchInitialTasks)
      task.schedule(after: self.fetchNextTasks)
      task.schedule(after: self.fetchPreviousTasks)
      self.fetchAllTasks.append(task)
    case .initialPage:
      self.fetchInitialTasks.append(task)
    case .nextPage:
      task.schedule(after: self.fetchInitialTasks)
      task.schedule(after: self.fetchAllTasks)
      self.fetchNextTasks.append(task)
    case .previousPage:
      task.schedule(after: self.fetchInitialTasks)
      task.schedule(after: self.fetchAllTasks)
      self.fetchPreviousTasks.append(task)
    }
  }

  public mutating func update(
    with result: Result<InfiniteQueryPages<PageID, PageValue>, any Error>,
    using context: QueryContext
  ) {
    switch result {
    case let .success(value):
      self.currentValue = value
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = context.queryClock.now()
      self.error = nil
    case let .failure(error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = context.queryClock.now()
    }
  }

  public mutating func update(
    with result: Result<InfiniteQueryValue<PageID, PageValue>, any Error>,
    for task: QueryTask<InfiniteQueryValue<PageID, PageValue>>
  ) {
    self.requests[task.id] = self.request(in: task.configuration.context)
    switch result {
    case let .success(value):
      switch value.response {
      case let .allPages(pages):
        self.currentValue = pages
        self.hasNextPage = pages.isEmpty || value.nextPageId != nil
        self.hasPreviousPage = pages.isEmpty || value.previousPageId != nil
      case let .initialPage(page):
        self.currentValue[id: page.id] = page
        self.hasNextPage = value.nextPageId != nil
        self.hasPreviousPage = value.previousPageId != nil
      case let .nextPage(next?):
        if let index = self.currentValue.firstIndex(where: { $0.id == next.lastPage.id }) {
          let (_, index) = self.currentValue.insert(next.page, at: index + 1)
          self.currentValue[index] = next.page
        }
        self.hasNextPage = value.nextPageId != nil
        self.hasPreviousPage = value.previousPageId != nil
      case let .previousPage(previous?):
        if let index = self.currentValue.firstIndex(where: { $0.id == previous.firstPage.id }) {
          let (_, index) = self.currentValue.insert(previous.page, at: index)
          self.currentValue[index] = previous.page
        }
        self.hasNextPage = value.nextPageId != nil
        self.hasPreviousPage = value.previousPageId != nil
      default: break
      }
      self.nextPageId = value.nextPageId
      self.previousPageId = value.previousPageId
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = task.configuration.context.queryClock.now()
      self.error = nil
    case let .failure(error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = task.configuration.context.queryClock.now()
    }
  }

  public mutating func finishFetchTask(_ task: QueryTask<InfiniteQueryValue<PageID, PageValue>>) {
    switch self.requests[task.id] {
    case .allPages:
      self.fetchAllTasks.remove(id: task.id)
    case .initialPage:
      self.fetchInitialTasks.remove(id: task.id)
    case .nextPage:
      self.fetchNextTasks.remove(id: task.id)
    case .previousPage:
      self.fetchPreviousTasks.remove(id: task.id)
    default: break
    }
    self.requests.removeValue(forKey: task.id)
  }

  func request(in context: QueryContext) -> InfiniteQueryPagingRequest<PageID> {
    guard let fetchType = context.infiniteValues.fetchType else {
      return self.currentValue.isEmpty ? .initialPage : .allPages
    }
    switch (fetchType, self.nextPageId, self.previousPageId) {
    case (.allPages, _, _):
      return .allPages
    case let (.nextPage, last?, _):
      return .nextPage(last)
    case let (.previousPage, _, first?):
      return .previousPage(first)
    default:
      return .initialPage
    }
  }
}
