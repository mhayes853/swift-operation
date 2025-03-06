import ConcurrencyExtras
import IdentifiedCollections

// MARK: - InfiniteQueryEventHandler

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

// MARK: - Erased

extension InfiniteQueryEventHandler {
  func erased() -> InfiniteQueryEventHandler<AnyHashableSendable, any Sendable> {
    InfiniteQueryEventHandler<AnyHashableSendable, any Sendable>(
      onFetchingStarted: self.onFetchingStarted,
      onPageFetchingStarted: { self.onPageFetchingStarted?($0.base as! PageID) },
      onPageResultReceived: { id, result in
        let newResult = result.map {
          InfiniteQueryPage(id: $0.id.base as! PageID, value: $0.value as! PageValue)
        }
        self.onPageResultReceived?(id.base as! PageID, newResult)
      },
      onResultReceived: { result in
        let newResult = result.map { pages in
          let array = pages.map {
            InfiniteQueryPage(id: $0.id.base as! PageID, value: $0.value as! PageValue)
          }
          return InfiniteQueryPages(uniqueElements: array)
        }
        self.onResultReceived?(newResult)
      },
      onPageFetchingFinished: { self.onPageFetchingFinished?($0.base as! PageID) },
      onFetchingFinished: self.onFetchingFinished
    )
  }
}
