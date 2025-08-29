import Foundation
import IdentifiedCollections

// MARK: - InfiniteOperationState

public protocol _InfiniteQueryStateProtocol<PageID, PageValue>: OperationState
where
  StateValue == InfiniteQueryPages<PageID, PageValue>,
  OperationValue == InfiniteQueryOperationValue<PageID, PageValue>,
  StatusValue == StateValue
{
  associatedtype PageID: Hashable & Sendable
  associatedtype PageValue: Sendable

  var initialPageId: PageID { get }
  var nextPageId: PageID? { get }
  var previousPageId: PageID? { get }
  var allPagesActiveTasks: IdentifiedArrayOf<OperationTask<OperationValue, any Error>> { get }
  var initialPageActiveTasks: IdentifiedArrayOf<OperationTask<OperationValue, any Error>> { get }
  var nextPageActiveTasks: IdentifiedArrayOf<OperationTask<OperationValue, any Error>> { get }
  var previousPageActiveTasks: IdentifiedArrayOf<OperationTask<OperationValue, any Error>> { get }
}

// MARK: - Has Page

extension _InfiniteQueryStateProtocol {
  /// Whether or not a next page can be fetched.
  public var hasNextPage: Bool {
    self.currentValue.isEmpty || self.nextPageId != nil
  }

  /// Whether or not a page before the first page in ``currentValue`` list can be fetched.
  public var hasPreviousPage: Bool {
    self.currentValue.isEmpty || self.previousPageId != nil
  }
}

// MARK: - Is Loading

extension _InfiniteQueryStateProtocol {
  /// Whether or not the next page is loading.
  public var isLoadingNextPage: Bool {
    !self.nextPageActiveTasks.isEmpty
  }

  /// Whether or not the next page that will be presented at the beginning of ``currentValue`` is loading.
  public var isLoadingPreviousPage: Bool {
    !self.previousPageActiveTasks.isEmpty
  }

  /// Whether or not all pages are being refetched.
  public var isLoadingAllPages: Bool {
    !self.allPagesActiveTasks.isEmpty
  }

  /// Whether or not the initial page is loading.
  public var isLoadingInitialPage: Bool {
    !self.initialPageActiveTasks.isEmpty
  }
}

// MARK: - InfiniteQueryState

/// A state type for ``InfiniteQueryRequest``.
///
/// Infinite queries can have tasks that either:
/// 1. Fetch the initial page of data.
/// 2. Fetch the next page of data.
///   - This can run concurrently with fetching the previous page of data.
/// 3. Fetch the previous page (ie. The page at the beginning of the list of pages.) of data.
///   - This can run concurrently with fetching the next page of data.
/// 4. Refetching all pages.
///
/// You can access all of these active tasks through ``allPagesActiveTasks``,
/// ``initialPageActiveTasks``, ``nextPageActiveTasks``, and ``previousPageActiveTasks``.
///
/// Additionally, the state keeps track of both ``nextPageId`` and ``previousPageId`` which are
/// obtained by calling the appropriate methods on ``InfiniteQueryRequest``.
///
/// > Warning: You should not call any of the `mutating` methods directly on this type, rather a
/// > ``OperationStore`` will call them at the appropriate time for you.
public struct InfiniteQueryState<PageID: Hashable & Sendable, PageValue: Sendable> {
  public let initialPageId: PageID
  public private(set) var currentValue: StateValue
  public let initialValue: StateValue
  public private(set) var valueUpdateCount = 0
  public private(set) var valueLastUpdatedAt: Date?

  public private(set) var error: (any Error)?
  public private(set) var errorUpdateCount = 0
  public private(set) var errorLastUpdatedAt: Date?

  /// The page id that will be passed to the driving query when
  /// ``OperationStore/fetchNextPage(using:handler:)`` is called.
  public private(set) var nextPageId: PageID?

  /// The page id that will be passed to the driving query when
  /// ``OperationStore/fetchPreviousPage(using:handler:)`` is called.
  public private(set) var previousPageId: PageID?

  /// The active ``OperationTask``s for refetching all pages of data.
  public private(set) var allPagesActiveTasks = IdentifiedArrayOf<
    OperationTask<InfiniteQueryOperationValue<PageID, PageValue>, any Error>
  >()

  /// The active ``OperationTask``s for fetching the initial page of data.
  public private(set) var initialPageActiveTasks = IdentifiedArrayOf<
    OperationTask<InfiniteQueryOperationValue<PageID, PageValue>, any Error>
  >()

  /// The active ``OperationTask``s for fetching the next page of data.
  public private(set) var nextPageActiveTasks = IdentifiedArrayOf<
    OperationTask<InfiniteQueryOperationValue<PageID, PageValue>, any Error>
  >()

  /// The active ``OperationTask``s for fetching the page of data that will be presented at the
  /// beginning of ``currentValue``.
  public private(set) var previousPageActiveTasks = IdentifiedArrayOf<
    OperationTask<InfiniteQueryOperationValue<PageID, PageValue>, any Error>
  >()

  public init(initialValue: StateValue, initialPageId: PageID) {
    self.currentValue = initialValue
    self.initialValue = initialValue
    self.initialPageId = initialPageId
  }
}

// MARK: - OperationState Conformance

extension InfiniteQueryState: _InfiniteQueryStateProtocol {
  public var isLoading: Bool {
    self.isLoadingAllPages || self.isLoadingNextPage || self.isLoadingPreviousPage
      || self.isLoadingInitialPage
  }

  public mutating func scheduleFetchTask(
    _ task: inout OperationTask<InfiniteQueryOperationValue<PageID, PageValue>, any Error>
  ) {
    switch self.request(in: task.context) {
    case .allPages:
      task.schedule(after: self.initialPageActiveTasks)
      task.schedule(after: self.nextPageActiveTasks)
      task.schedule(after: self.previousPageActiveTasks)
      task.context.infiniteValues?.currentPagesTracker =
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

  public mutating func reset(using context: OperationContext) -> ResetEffect {
    let tasksToCancel =
      self.initialPageActiveTasks + self.nextPageActiveTasks
      + self.previousPageActiveTasks + self.allPagesActiveTasks
    self = Self(initialValue: self.initialValue, initialPageId: self.initialPageId)
    return ResetEffect(tasksToCancel: tasksToCancel)
  }

  public mutating func update(
    with result: Result<InfiniteQueryPages<PageID, PageValue>, any Error>,
    using context: OperationContext
  ) {
    switch result {
    case .success(let value):
      self.currentValue = value
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = context.operationClock.now()
      self.error = nil
    case .failure(let error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = context.operationClock.now()
    }
  }

  public mutating func update(
    with result: Result<InfiniteQueryOperationValue<PageID, PageValue>, any Error>,
    for task: OperationTask<InfiniteQueryOperationValue<PageID, PageValue>, any Error>
  ) {
    switch result {
    case .success(let value):
      switch value.fetchValue {
      case .allPages(let pages):
        self.currentValue = pages
      case .initialPage(let page):
        if task.context.infiniteValues?.fetchType != nil {
          self.currentValue[id: page.id] = page
        } else {
          self.currentValue = [page]
        }
      case .nextPage(let next):
        if let index = self.currentValue.firstIndex(where: { $0.id == next.lastPageId }) {
          let (_, index) = self.currentValue.insert(next.page, at: index + 1)
          self.currentValue[index] = next.page
        }
      case .previousPage(let previous):
        if let index = self.currentValue.firstIndex(where: { $0.id == previous.firstPageId }) {
          let (_, index) = self.currentValue.insert(previous.page, at: index)
          self.currentValue[index] = previous.page
        }
      }
      self.nextPageId = value.nextPageId
      self.previousPageId = value.previousPageId
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = task.context.operationClock.now()
      self.error = nil
    case .failure(let error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = task.context.operationClock.now()
    }
  }

  public mutating func finishFetchTask(
    _ task: OperationTask<InfiniteQueryOperationValue<PageID, PageValue>, any Error>
  ) {
    self.allPagesActiveTasks.remove(id: task.id)
    self.initialPageActiveTasks.remove(id: task.id)
    self.nextPageActiveTasks.remove(id: task.id)
    self.previousPageActiveTasks.remove(id: task.id)
  }

  func request(in context: OperationContext) -> InfiniteQueryPagingRequest<PageID> {
    guard let fetchType = context.infiniteValues?.fetchType else {
      return .initialPage
    }
    switch (fetchType, self.nextPageId, self.previousPageId) {
    case (.allPages, _, _):
      return .allPages
    case (.nextPage, let last?, _):
      return .nextPage(last)
    case (.previousPage, _, let first?):
      return .previousPage(first)
    default:
      return .initialPage
    }
  }
}

// MARK: - DefaultableOperationState

extension InfiniteQueryState: DefaultableOperationState {
  public typealias DefaultStateValue = StateValue

  public func defaultValue(
    for value: StateValue,
    using defaultValue: DefaultStateValue
  ) -> DefaultStateValue {
    self.valueUpdateCount == 0 ? defaultValue : value
  }

  public func stateValue(for defaultStateValue: DefaultStateValue) -> StateValue {
    defaultStateValue
  }
}

extension DefaultOperationState: _InfiniteQueryStateProtocol
where Base: _InfiniteQueryStateProtocol, Base.DefaultStateValue == Base.StateValue {
  public typealias PageID = Base.PageID
  public typealias PageValue = Base.PageValue

  public var initialPageId: PageID { self.base.initialPageId }
  public var nextPageId: PageID? { self.base.nextPageId }
  public var previousPageId: PageID? { self.base.previousPageId }

  public var allPagesActiveTasks: IdentifiedArrayOf<OperationTask<Base.OperationValue, any Error>> {
    self.base.allPagesActiveTasks
  }

  public var initialPageActiveTasks:
    IdentifiedArrayOf<OperationTask<Base.OperationValue, any Error>>
  {
    self.base.initialPageActiveTasks
  }

  public var nextPageActiveTasks: IdentifiedArrayOf<OperationTask<Base.OperationValue, any Error>> {
    self.base.nextPageActiveTasks
  }

  public var previousPageActiveTasks:
    IdentifiedArrayOf<OperationTask<Base.OperationValue, any Error>>
  {
    self.base.previousPageActiveTasks
  }
}

extension DefaultOperation where Operation: InfiniteQueryRequest {
  package var initialState: State {
    State(
      Operation.State(initialValue: [], initialPageId: self.operation.initialPageId),
      defaultValue: self.defaultValue
    )
  }
}
