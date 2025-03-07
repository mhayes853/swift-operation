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

  public private(set) var isLoadingNextPage = false
  public private(set) var isLoadingPreviousPage = false
  public private(set) var isLoadingAllPages = false
  public private(set) var isLoadingInitialPage = false

  public private(set) var error: (any Error)?
  public private(set) var errorUpdateCount = 0
  public private(set) var errorLastUpdatedAt: Date?

  public private(set) var hasNextPage = true
  public private(set) var hasPreviousPage = true
  public private(set) var nextPageId: PageID?
  public private(set) var previousPageId: PageID?

  private var fetchAllTask: QueryTask<QueryValue>?
  private var fetchInitialTask: QueryTask<QueryValue>?
  private var fetchNextPageTask: QueryTask<QueryValue>?
  private var fetchPreviousPageTask: QueryTask<QueryValue>?

  init(initialValue: StateValue, initialPageId: PageID) {
    self.currentValue = initialValue
    self.initialValue = initialValue
    self.initialPageId = initialPageId
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

  public mutating func startFetchTask(
    _ task: QueryTask<InfiniteQueryValue<PageID, PageValue>>
  ) -> QueryTask<InfiniteQueryValue<PageID, PageValue>> {
    let request = self.request(in: task.context)
    var task = task
    switch request {
    case .allPages:
      defer { self.fetchAllTask = task }
      if let fetchAllTask {
        task = fetchAllTask
      } else {
        task.optionallyDepend(on: [
          self.fetchInitialTask, self.fetchNextPageTask, self.fetchPreviousPageTask
        ])
      }
    case .initialPage:
      defer { self.fetchInitialTask = task }
      self.isLoadingInitialPage = true
      task = self.fetchInitialTask ?? task
    case .nextPage:
      defer { self.fetchNextPageTask = task }
      if let fetchNextPageTask {
        task = fetchNextPageTask
      } else {
        task.optionallyDepend(on: [self.fetchInitialTask, self.fetchAllTask])
      }
    case .previousPage:
      defer { self.fetchPreviousPageTask = task }
      if let fetchPreviousPageTask {
        task = fetchPreviousPageTask
      } else {
        task.optionallyDepend(on: [self.fetchInitialTask, self.fetchAllTask])
      }
    }
    switch task.context.infiniteValues.fetchType {
    case .allPages:
      self.isLoadingAllPages = true
    case .nextPage:
      self.isLoadingNextPage = true
    case .previousPage:
      self.isLoadingPreviousPage = true
    default: break
    }
    return task
  }

  public mutating func endFetchTask(
    _ task: QueryTask<InfiniteQueryValue<PageID, PageValue>>,
    with result: Result<InfiniteQueryValue<PageID, PageValue>, any Error>
  ) {
    let originalRequest = self.request(in: task.context)
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
          self.currentValue.insert(next.page, at: index + 1)
        }
        self.hasNextPage = value.nextPageId != nil
        self.hasPreviousPage = value.previousPageId != nil
      case let .previousPage(previous?):
        if let index = self.currentValue.firstIndex(where: { $0.id == previous.firstPage.id }) {
          self.currentValue.insert(previous.page, at: index)
        }
        self.hasNextPage = value.nextPageId != nil
        self.hasPreviousPage = value.previousPageId != nil
      default: break
      }
      self.nextPageId = value.nextPageId
      self.previousPageId = value.previousPageId
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = task.context.queryClock.now()
      self.error = nil
    case let .failure(error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = task.context.queryClock.now()
    }

    switch originalRequest {
    case .allPages:
      self.fetchAllTask = nil
      self.isLoadingAllPages = false
    case .initialPage:
      self.fetchInitialTask = nil
      self.isLoadingInitialPage = false
      self.isLoadingNextPage = false
      self.isLoadingPreviousPage = false
    case .nextPage:
      self.fetchNextPageTask = nil
      self.isLoadingNextPage = false
    case .previousPage:
      self.fetchPreviousPageTask = nil
      self.isLoadingPreviousPage = false
    }
  }

  func request(in context: QueryContext) -> InfiniteQueryPaging<PageID, PageValue>.Request {
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

extension QueryTask {
  fileprivate mutating func optionallyDepend(on tasks: [Self?]) {
    self.depend(on: tasks.compactMap { $0 })
  }
}
