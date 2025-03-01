import IdentifiedCollections

public struct InfiniteQueryEventHandler<
  PageID: Hashable & Sendable,
  PageValue: Sendable
>: Sendable {
  let onFetchingStarted: (@Sendable () -> Void)?
  let onPageFetchingStarted: (@Sendable (PageID) -> Void)?
  let onPageResultReceived:
    (@Sendable (PageID, Result<InfiniteQueryPage<PageID, PageValue>, any Error>) -> Void)?
  let onResultReceived:
    (@Sendable (Result<InfiniteQueryPages<PageID, PageValue>, any Error>) -> Void)?
  let onPageFetchingFinished: (@Sendable (PageID) -> Void)?
  let onFetchingFinished: (@Sendable () -> Void)?

  public init(
    onFetchingStarted: (@Sendable () -> Void)? = nil,
    onPageFetchingStarted: (@Sendable (PageID) -> Void)? = nil,
    onPageResultReceived: (
      @Sendable (PageID, Result<InfiniteQueryPage<PageID, PageValue>, any Error>) -> Void
    )? = nil,
    onResultReceived: (
      @Sendable (Result<InfiniteQueryPages<PageID, PageValue>, any Error>) -> Void
    )? = nil,
    onPageFetchingFinished: (@Sendable (PageID) -> Void)? = nil,
    onFetchingFinished: (@Sendable () -> Void)? = nil
  ) {
    self.onFetchingStarted = onFetchingStarted
    self.onPageFetchingStarted = onPageFetchingStarted
    self.onPageResultReceived = onPageResultReceived
    self.onResultReceived = onResultReceived
    self.onPageFetchingFinished = onPageFetchingFinished
    self.onFetchingFinished = onFetchingFinished
  }
}
