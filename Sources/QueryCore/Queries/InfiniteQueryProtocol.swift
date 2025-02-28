import IdentifiedCollections

// MARK: - InfiniteQueryPage

public struct InfiniteQueryPage<ID: Hashable & Sendable, Value: Sendable>: Sendable, Identifiable {
  public var id: ID
  public var values: [Value]

  public init(id: ID, values: [Value]) {
    self.id = id
    self.values = values
  }
}

extension InfiniteQueryPage: Equatable where Value: Equatable {}
extension InfiniteQueryPage: Hashable where Value: Hashable {}

// MARK: - InfiniteQueryPages

public typealias InfiniteQueryPages<PageID: Hashable & Sendable, PageValue: Sendable> =
  IdentifiedArrayOf<InfiniteQueryPage<PageID, PageValue>>

// MARK: - InfiniteQueryProtocol

public protocol InfiniteQueryProtocol<PageID, PageValue>: QueryProtocol {
  associatedtype PageValue: Sendable
  associatedtype PageID: Hashable & Sendable
  associatedtype Value = InfiniteQueryPages<PageID, PageValue>

  var initialPageId: PageID { get }

  func pageId(after page: InfiniteQueryPage<PageID, PageValue>, pages: Value) -> PageID?
  func pageId(before page: InfiniteQueryPage<PageID, PageValue>, pages: Value) -> PageID?
  func fetchPage(for id: PageID, in context: QueryContext, pages: Value) async throws -> PageValue
}

extension InfiniteQueryProtocol {
  public func pageId(before page: InfiniteQueryPage<PageID, PageValue>, pages: Value) -> PageID? {
    nil
  }

  public func fetch(in context: QueryContext) async throws -> Value {
    fatalError("TODO")
  }
}
