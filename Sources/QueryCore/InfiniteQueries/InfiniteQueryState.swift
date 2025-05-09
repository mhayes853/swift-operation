import Foundation
import IdentifiedCollections

// MARK: - InfiniteQueryStateProtocol

public protocol _InfiniteQueryStateProtocol<PageID, PageValue>: QueryStateProtocol
where
  StateValue == InfiniteQueryPages<PageID, PageValue>,
  QueryValue == InfiniteQueryValue<PageID, PageValue>,
  StatusValue == StateValue
{
  associatedtype PageID: Hashable & Sendable
  associatedtype PageValue: Sendable

  var hasPreviousPage: Bool { get }
  var hasNextPage: Bool { get }
}

// MARK: - InfiniteQueryState

/// > Warning: You should not call any of the `mutating` methods directly on this type, rather a
/// > ``QueryStore`` will call them at the appropriate time for you.
public struct InfiniteQueryState<PageID: Hashable & Sendable, PageValue: Sendable> {
  public let initialPageId: PageID
  public private(set) var currentValue: StateValue
  public let initialValue: StateValue
  public private(set) var valueUpdateCount = 0
  public private(set) var valueLastUpdatedAt: Date?

  public private(set) var error: (any Error)?
  public private(set) var errorUpdateCount = 0
  public private(set) var errorLastUpdatedAt: Date?

  public private(set) var nextPageId: PageID?
  public private(set) var previousPageId: PageID?

  public private(set) var allPagesActiveTasks = IdentifiedArrayOf<QueryTask<QueryValue>>()
  public private(set) var initialPageActiveTasks = IdentifiedArrayOf<QueryTask<QueryValue>>()
  public private(set) var nextPageActiveTasks = IdentifiedArrayOf<QueryTask<QueryValue>>()
  public private(set) var previousPageActiveTasks = IdentifiedArrayOf<QueryTask<QueryValue>>()

  public init(initialValue: StateValue, initialPageId: PageID) {
    self.currentValue = initialValue
    self.initialValue = initialValue
    self.initialPageId = initialPageId
  }
}

// MARK: - Is Loading

extension InfiniteQueryState {
  public var isLoadingNextPage: Bool {
    !self.nextPageActiveTasks.isEmpty
  }

  public var isLoadingPreviousPage: Bool {
    !self.previousPageActiveTasks.isEmpty
  }

  public var isLoadingAllPages: Bool {
    !self.allPagesActiveTasks.isEmpty
  }

  public var isLoadingInitialPage: Bool {
    !self.initialPageActiveTasks.isEmpty
  }
}

// MARK: - Has Page

extension InfiniteQueryState {
  public var hasNextPage: Bool {
    self.currentValue.isEmpty || self.nextPageId != nil
  }

  public var hasPreviousPage: Bool {
    self.currentValue.isEmpty || self.previousPageId != nil
  }
}

// MARK: - QueryStateProtocol Conformance

extension InfiniteQueryState: _InfiniteQueryStateProtocol {
  public var isLoading: Bool {
    self.isLoadingAllPages || self.isLoadingNextPage || self.isLoadingPreviousPage
      || self.isLoadingInitialPage
  }

  public mutating func scheduleFetchTask(
    _ task: inout QueryTask<InfiniteQueryValue<PageID, PageValue>>
  ) {
    switch self.request(in: task.configuration.context) {
    case .allPages:
      task.schedule(after: self.initialPageActiveTasks)
      task.schedule(after: self.nextPageActiveTasks)
      task.schedule(after: self.previousPageActiveTasks)
      task.configuration.context.infiniteValues.currentPagesTracker =
        InfiniteQueryContextValues.PagesTracker()
      self.allPagesActiveTasks.append(task)
    case .initialPage:
      self.initialPageActiveTasks.append(task)
    case .nextPage:
      task.schedule(after: self.initialPageActiveTasks)
      task.schedule(after: self.allPagesActiveTasks)
      self.nextPageActiveTasks.append(task)
    case .previousPage:
      task.schedule(after: self.initialPageActiveTasks)
      task.schedule(after: self.allPagesActiveTasks)
      self.previousPageActiveTasks.append(task)
    }
  }

  public mutating func reset(using context: QueryContext) {
    self.initialPageActiveTasks.forEach { $0.cancel() }
    self.nextPageActiveTasks.forEach { $0.cancel() }
    self.previousPageActiveTasks.forEach { $0.cancel() }
    self.allPagesActiveTasks.forEach { $0.cancel() }
    self = Self(initialValue: self.initialValue, initialPageId: self.initialPageId)
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
    switch result {
    case let .success(value):
      switch value.response {
      case let .allPages(pages):
        self.currentValue = pages
      case let .initialPage(page):
        self.currentValue[id: page.id] = page
      case let .nextPage(next?):
        if let index = self.currentValue.firstIndex(where: { $0.id == next.lastPage.id }) {
          let (_, index) = self.currentValue.insert(next.page, at: index + 1)
          self.currentValue[index] = next.page
        }
      case let .previousPage(previous?):
        if let index = self.currentValue.firstIndex(where: { $0.id == previous.firstPage.id }) {
          let (_, index) = self.currentValue.insert(previous.page, at: index)
          self.currentValue[index] = previous.page
        }
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
    self.allPagesActiveTasks.remove(id: task.id)
    self.initialPageActiveTasks.remove(id: task.id)
    self.nextPageActiveTasks.remove(id: task.id)
    self.previousPageActiveTasks.remove(id: task.id)
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
