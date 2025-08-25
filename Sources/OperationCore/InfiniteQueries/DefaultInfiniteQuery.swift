import IdentifiedCollections

extension InfiniteQueryRequest {
  /// Adds a default value to this query.
  ///
  /// - Parameter value: The default value for this query.
  /// - Returns: A ``DefaultInfiniteQuery``.
  public func defaultValue(
    _ value: @autoclosure @escaping @Sendable () -> State.StateValue
  ) -> DefaultInfiniteQuery<Self> {
    DefaultInfiniteQuery(_defaultValue: value, query: self)
  }
}

/// A query that provides a default value to an ``InfiniteQueryRequest``.
///
/// You create instances of this query through ``InfiniteQueryRequest/defaultValue(_:)``.
public struct DefaultInfiniteQuery<Query: InfiniteQueryRequest>: OperationRequest {
  let _defaultValue: @Sendable () -> Query.State.StateValue

  /// The base query.
  public let query: Query

  /// The default value of this query.
  public var defaultValue: Query.State.StateValue {
    self._defaultValue()
  }

  public var path: OperationPath {
    self.query.path
  }

  public var _debugTypeName: String {
    self.query._debugTypeName
  }

  public func setup(context: inout OperationContext) {
    self.query.setup(context: &context)
  }

  public func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await self.query.fetch(isolation: isolation, in: context, with: continuation)
  }
}

extension DefaultInfiniteQuery: InfiniteQueryRequest {
  public typealias PageValue = Query.PageValue
  public typealias PageID = Query.PageID
  public typealias State = Query.State

  public var initialPageId: PageID {
    self.query.initialPageId
  }

  public func pageId(
    after page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext
  ) -> PageID? {
    self.query.pageId(after: page, using: paging, in: context)
  }

  public func pageId(
    before page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext
  ) -> PageID? {
    self.query.pageId(before: page, using: paging, in: context)
  }

  public func fetchPage(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: OperationContext,
    with continuation: OperationContinuation<PageValue>
  ) async throws -> PageValue {
    try await self.query.fetchPage(using: paging, in: context, with: continuation)
  }
}
