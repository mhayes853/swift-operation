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

  private var fetchAllTask: Task<any Sendable, any Error>?
  private var fetchInitialTask: Task<any Sendable, any Error>?
  private var fetchNextPageTask: Task<any Sendable, any Error>?
  private var fetchPreviousPageTask: Task<any Sendable, any Error>?

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
    in context: QueryContext,
    for fn: @escaping @Sendable () async throws -> any Sendable
  ) -> Task<any Sendable, any Error> {
    let request = context.infiniteValues?.request(PageID.self, PageValue.self) ?? .allPages
    var task: Task<any Sendable, any Error>
    switch request {
    case .allPages:
      defer { self.fetchAllTask = task }
      task =
        self.fetchAllTask
        ?? Task { [self] in
          _ = try? await self.fetchInitialTask?.cancellableValue
          _ = try? await self.fetchNextPageTask?.cancellableValue
          _ = try? await self.fetchPreviousPageTask?.cancellableValue
          return try await fn()
        }

    case .initialPage:
      defer { self.fetchInitialTask = task }
      self.isLoadingInitialPage = true
      task = self.fetchInitialTask ?? Task { try await fn() }

    case .nextPageAfter:
      defer { self.fetchNextPageTask = task }
      task =
        self.fetchNextPageTask
        ?? Task { [self] in
          _ = try? await self.fetchInitialTask?.cancellableValue
          _ = try? await self.fetchAllTask?.cancellableValue
          return try await fn()
        }

    case .previousPageBefore:
      defer { self.fetchPreviousPageTask = task }
      task =
        self.fetchPreviousPageTask
        ?? Task { [self] in
          _ = try? await self.fetchInitialTask?.cancellableValue
          _ = try? await self.fetchAllTask?.cancellableValue
          return try await fn()
        }
    }
    switch context.infiniteValues?.fetchType {
    case .nextPage:
      self.isLoadingNextPage = true
    case .previousPage:
      self.isLoadingPreviousPage = true
    case .allPages, .none:
      self.isLoadingAllPages = true
    }
    return task
  }

  public mutating func endFetchTask(
    in context: QueryContext,
    with result: Result<QueryValue, Error>
  ) {
    switch result {
    case let .success(value):
      switch value {
      case let .allPages(pages):
        self.currentValue = pages
      case let .initialPage(page):
        self.currentValue[id: page.id] = page
      case let .nextPage(next?):
        if let index = self.currentValue.firstIndex(where: { $0.id == next.previousPage.id }) {
          self.currentValue.insert(next.page, at: index + 1)
        }
      case let .previousPage(previous?):
        if let index = self.currentValue.firstIndex(where: { $0.id == previous.nextPage.id }) {
          self.currentValue.insert(previous.page, at: index)
        }
      default: break
      }

      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = context.queryClock.now()
      self.error = nil
    case let .failure(error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = context.queryClock.now()
    }

    let request = context.infiniteValues?.request(PageID.self, PageValue.self) ?? .allPages
    switch request {
    case .allPages:
      self.fetchAllTask = nil
      self.isLoadingAllPages = false
    case .initialPage:
      self.fetchInitialTask = nil
      self.isLoadingInitialPage = false
      self.isLoadingNextPage = false
      self.isLoadingPreviousPage = false
    case .nextPageAfter:
      self.fetchNextPageTask = nil
      self.isLoadingNextPage = false
    case .previousPageBefore:
      self.fetchPreviousPageTask = nil
      self.isLoadingPreviousPage = false
    }
  }
}
