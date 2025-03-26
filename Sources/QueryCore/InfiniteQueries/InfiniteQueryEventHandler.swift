import ConcurrencyExtras
import IdentifiedCollections

// MARK: - InfiniteQueryEventHandler

public struct InfiniteQueryEventHandler<
  PageID: Hashable & Sendable,
  PageValue: Sendable
>: Sendable {
  public var onStateChanged:
    (@Sendable (InfiniteQueryState<PageID, PageValue>, QueryContext) -> Void)?
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

  public init(
    onStateChanged: (@Sendable (InfiniteQueryState<PageID, PageValue>, QueryContext) -> Void)? =
      nil,
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
    onFetchingFinished: (@Sendable (QueryContext) -> Void)? = nil
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
