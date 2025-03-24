import ConcurrencyExtras
import IdentifiedCollections

// MARK: - InfiniteQueryEventHandler

public struct InfiniteQueryEventHandler<
  PageID: Hashable & Sendable,
  PageValue: Sendable
>: Sendable {
  public var onFetchingStarted: (@Sendable (QueryContext) -> Void)?
  public var onPageFetchingStarted: (@Sendable (PageID, QueryContext) -> Void)?
  public var onPageResultReceived:
    (
      @Sendable (PageID, Result<InfiniteQueryPage<PageID, PageValue>, any Error>, QueryContext) ->
        Void
    )?
  public var onResultReceived:
    (@Sendable (Result<InfiniteQueryPages<PageID, PageValue>, any Error>, QueryContext) -> Void)?
  public var onPageFetchingFinished: (@Sendable (PageID, QueryContext) -> Void)?
  public var onFetchingFinished: (@Sendable (QueryContext) -> Void)?
  public var onStateChanged:
    (@Sendable (InfiniteQueryState<PageID, PageValue>, QueryContext) -> Void)?

  public init(
    onFetchingStarted: (@Sendable (QueryContext) -> Void)? = nil,
    onPageFetchingStarted: (@Sendable (PageID, QueryContext) -> Void)? = nil,
    onPageResultReceived: (
      @Sendable (PageID, Result<InfiniteQueryPage<PageID, PageValue>, any Error>, QueryContext) ->
        Void
    )? = nil,
    onResultReceived: (
      @Sendable (Result<InfiniteQueryPages<PageID, PageValue>, any Error>, QueryContext) -> Void
    )? = nil,
    onPageFetchingFinished: (@Sendable (PageID, QueryContext) -> Void)? = nil,
    onFetchingFinished: (@Sendable (QueryContext) -> Void)? = nil,
    onStateChanged: (@Sendable (InfiniteQueryState<PageID, PageValue>, QueryContext) -> Void)? = nil
  ) {
    self.onFetchingStarted = onFetchingStarted
    self.onPageFetchingStarted = onPageFetchingStarted
    self.onPageResultReceived = onPageResultReceived
    self.onResultReceived = onResultReceived
    self.onPageFetchingFinished = onPageFetchingFinished
    self.onFetchingFinished = onFetchingFinished
    self.onStateChanged = onStateChanged
  }
}

// MARK: - Erased

extension InfiniteQueryEventHandler {
  func erased() -> InfiniteQueryEventHandler<AnyHashableSendable, any Sendable> {
    InfiniteQueryEventHandler<AnyHashableSendable, any Sendable>(
      onFetchingStarted: self.onFetchingStarted,
      onPageFetchingStarted: { self.onPageFetchingStarted?($0.base as! PageID, $1) },
      onPageResultReceived: { id, result, context in
        let newResult = result.map {
          InfiniteQueryPage(id: $0.id.base as! PageID, value: $0.value as! PageValue)
        }
        self.onPageResultReceived?(id.base as! PageID, newResult, context)
      },
      onResultReceived: { result, context in
        let newResult = result.map { pages in
          let array = pages.map {
            InfiniteQueryPage(id: $0.id.base as! PageID, value: $0.value as! PageValue)
          }
          return InfiniteQueryPages(uniqueElements: array)
        }
        self.onResultReceived?(newResult, context)
      },
      onPageFetchingFinished: { self.onPageFetchingFinished?($0.base as! PageID, $1) },
      onFetchingFinished: self.onFetchingFinished
    )
  }
}
