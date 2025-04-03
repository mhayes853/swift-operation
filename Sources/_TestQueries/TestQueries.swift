import Query

// MARK: - TestQuery

package struct TestQuery: QueryRequest, Hashable {
  package static let value = 1

  package init() {}

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Int>
  ) async throws -> Int {
    Self.value
  }
}

// MARK: - TestStringQuery

package struct TestStringQuery: QueryRequest, Hashable {
  package static let value = "Foo"

  package init() {}

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    Self.value
  }
}

// MARK: - TestStateQuery

package struct TestStateQuery: QueryRequest, Hashable {
  package enum Action {
    case load, suspend, fail
  }

  package static let action = Lock(Action.load)

  package static let successValue = "Success"

  package typealias Value = String

  package init() {}

  package struct SomeError: Hashable, Error {
    package init() {}
  }

  package func setup(context: inout QueryContext) {
    context.enableAutomaticFetchingCondition = .always(false)
  }

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value {
    let task = Self.action.withLock { action in
      switch action {
      case .load:
        return Task { () async throws -> String in
          return Self.successValue
        }
      case .suspend:
        return Task {
          try await Task.never()
          throw SomeError()
        }
      case .fail:
        return Task { throw SomeError() }
      }
    }
    return try await task.value
  }
}

// MARK: - EndlessQuery

package final class SleepingQuery: QueryRequest, @unchecked Sendable {
  package var didBeginSleeping: (() -> Void)?

  private let continuation = Lock<UnsafeContinuation<Void, any Error>?>(nil)

  package init() {}

  package var path: QueryPath {
    ["test-sleeping"]
  }

  package func resume() {
    self.continuation.withLock { $0?.resume() }
  }

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    try await withTaskCancellationHandler {
      try await withUnsafeThrowingContinuation { continuation in
        self.continuation.withLock { $0 = continuation }
        self.didBeginSleeping?()
      }
    } onCancel: {
      self.continuation.withLock { $0?.resume(throwing: CancellationError()) }
    }
    return ""
  }
}

// MARK: - FailingQuery

package struct FailingQuery: QueryRequest, Hashable {
  package struct SomeError: Equatable, Error {
    package init() {}
  }

  package init() {}

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    throw SomeError()
  }
}

// MARK: - CountingQuery

package final actor CountingQuery: QueryRequest {
  package var fetchCount = 0
  private var shouldFail = false
  private let sleep: @Sendable () async -> Void

  package init(sleep: @Sendable @escaping () async -> Void = { await Task.megaYield() }) {
    self.sleep = sleep
  }

  nonisolated package var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  package func ensureFails() {
    self.shouldFail = true
  }

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Int>
  ) async throws -> Int {
    await self.sleep()
    self.fetchCount += 1
    if self.shouldFail {
      throw SomeError()
    }
    return self.fetchCount
  }

  package struct SomeError: Equatable, Error {
    package init() {}
  }
}

// MARK: - EndlesQuery

package struct EndlessQuery: QueryRequest, Hashable {
  package init() {}

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    try await Task.never()
    return ""
  }
}

// MARK: - NonCancellingEndlessQuery

package struct NonCancellingEndlessQuery: QueryRequest, Hashable {
  package init() {}

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    try? await Task.never()
    continuation.yield("blob")
    return ""
  }
}

// MARK: - FailableQuery

package final actor FlakeyQuery: QueryRequest {
  private var result: String?

  package init() {}

  nonisolated package var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  package func ensureSuccess(result: String) {
    self.result = result
  }

  package func ensureFailure() {
    self.result = nil
  }

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    guard let result else { throw SomeError() }
    return result
  }

  package struct SomeError: Equatable, Error {
    package init() {}
  }
}

// MARK: - PathableQuery

package struct PathableQuery: QueryRequest {
  package let value: Int
  package let path: QueryPath

  package init(value: Int, path: QueryPath) {
    self.value = value
    self.path = path
  }

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Int>
  ) async throws -> Int {
    self.value
  }
}

// MARK: - SucceedOnNthRefetchQuery

package struct SucceedOnNthRefetchQuery: QueryRequest, Hashable {
  package static let value = "refetch success"

  package let index: Int

  package init(index: Int) {
    self.index = index
  }

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    if context.queryRetryIndex < self.index {
      throw SomeError()
    }
    return Self.value
  }

  package struct SomeError: Error {
    package init() {}
  }
}

// MARK: - ContextReadingQuery

package final actor ContextReadingQuery: QueryRequest {
  package var latestContext: QueryContext?

  package init() {}

  nonisolated package var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    self.latestContext = context
    return ""
  }
}

// MARK: - ContinuingQuery

package final class ContinuingQuery: QueryRequest, @unchecked Sendable {
  package static let values = ["blob", "blob jr", "blob sr"]
  package static let finalValue = "the end"

  package var onYield: ((String) -> Void)?

  package init() {}

  package var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    for value in Self.values {
      continuation.yield(value)
    }
    return Self.finalValue
  }
}

// MARK: - ContinuingErrorQuery

package struct ContinuingErrorQuery: QueryRequest, Hashable {
  package static let finalValue = "the end"

  package init() {}

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    continuation.yield(error: SomeError())
    return Self.finalValue
  }

  package struct SomeError: Equatable, Error {
    package init() {}
  }
}

// MARK: - ContinuingValueThenErrorQuery

package struct ContinuingValueThenErrorQuery: QueryRequest, Hashable {
  package static let value = "the end"

  package init() {}

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    continuation.yield(Self.value)
    throw SomeError()
  }

  package struct SomeError: Equatable, Error {
    package init() {}
  }
}

// MARK: - TestInfiniteQuery

package struct EmptyInfiniteQuery: InfiniteQueryRequest {
  package let initialPageId: Int
  package let path: QueryPath

  package init(initialPageId: Int, path: QueryPath) {
    self.initialPageId = initialPageId
    self.path = path
  }

  package func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    nil
  }

  package func pageId(
    before page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    nil
  }

  package func fetchPage(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    ""
  }
}

package struct EmptyIntInfiniteQuery: InfiniteQueryRequest {
  package let initialPageId: Int
  package let path: QueryPath

  package init(initialPageId: Int, path: QueryPath) {
    self.initialPageId = initialPageId
    self.path = path
  }

  package func pageId(
    after page: InfiniteQueryPage<Int, Int>,
    using paging: InfiniteQueryPaging<Int, Int>,
    in context: QueryContext
  ) -> Int? {
    nil
  }

  package func pageId(
    before page: InfiniteQueryPage<Int, Int>,
    using paging: InfiniteQueryPaging<Int, Int>,
    in context: QueryContext
  ) -> Int? {
    nil
  }

  package func fetchPage(
    using paging: InfiniteQueryPaging<Int, Int>,
    in context: QueryContext,
    with continuation: QueryContinuation<Int>
  ) async throws -> Int {
    0
  }
}

// MARK: - FakeInfiniteQuery

package struct FakeInfiniteQuery: QueryRequest, Hashable {
  package typealias State = InfiniteQueryState<Int, String>
  package typealias Value = InfiniteQueryValue<Int, String>

  package init() {}

  package func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value {
    fatalError()
  }
}

// MARK: - TestInfiniteQuery

package final class TestInfiniteQuery: InfiniteQueryRequest {
  package let initialPageId = 0

  package let state = RecursiveLock([Int: String]())

  package init() {}

  package var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  package func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    self.state.withLock { $0[page.id + 1] != nil ? page.id + 1 : nil }
  }

  package func pageId(
    before page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    self.state.withLock { $0[page.id - 1] != nil ? page.id - 1 : nil }
  }

  package func fetchPage(
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    try self.state.withLock {
      if let value = $0[paging.pageId] {
        return value
      }
      throw PageNotFoundError()
    }
  }

  package struct PageNotFoundError: Error {
    package init() {}
  }
}

// MARK: - CountingInfiniteQuery

package final actor CountingInfiniteQuery: InfiniteQueryRequest {
  package let initialPageId = 0

  package var fetchCount = 0

  package init() {}

  package func resetCount() {
    self.fetchCount = 0
  }

  nonisolated package var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  nonisolated package func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    page.id + 1
  }

  nonisolated package func pageId(
    before page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    page.id - 1
  }

  package func fetchPage(
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    await Task.megaYield()
    self.fetchCount += 1
    return "blob"
  }
}

// MARK: - FlakeyInfiniteQuery

package final class FlakeyInfiniteQuery: InfiniteQueryRequest {
  package typealias PageValue = String
  package typealias PageID = Int

  package typealias Values = (failOnPageId: Int, fetchCount: Int)

  package let values = RecursiveLock<Values>((failOnPageId: 0, fetchCount: 0))

  package let initialPageId = 0

  package init() {}

  package var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  package func pageId(
    after page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) -> PageID? {
    page.id + 1
  }

  package func fetchPage(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext,
    with continuation: QueryContinuation<PageValue>
  ) async throws -> PageValue {
    try self.values.withLock { values in
      values.fetchCount += 1
      if values.failOnPageId == paging.pageId {
        throw SomeError()
      }
      return "blob"
    }
  }

  package struct SomeError: Equatable, Error {
    package init() {}
  }
}

// MARK: - TestYieldableInfiniteQuery

package final class TestYieldableInfiniteQuery: InfiniteQueryRequest {
  package static func finalValue(for id: PageID) -> String {
    "page final value \(id)"
  }

  package static func finalPage(for id: PageID) -> InfiniteQueryPage<Int, String> {
    InfiniteQueryPage(id: id, value: finalValue(for: id))
  }

  package let initialPageId = 0
  let shouldThrow: Bool

  package init(shouldThrow: Bool = false) {
    self.shouldThrow = shouldThrow
  }

  package let state = RecursiveLock([Int: [Result<PageValue, any Error>]]())

  package var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  package func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    page.id + 1
  }

  package func pageId(
    before page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    page.id - 1
  }

  package func fetchPage(
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    self.state.withLock {
      for result in $0[paging.pageId] ?? [] {
        continuation.yield(with: result)
      }
    }
    if self.shouldThrow {
      throw TestYieldableInfiniteQuery.SomeError()
    }
    return Self.finalValue(for: paging.pageId)
  }

  package struct SomeError: Equatable, Error {
    package init() {}
  }
}

// MARK: - WaitableInfiniteQuery

package final class WaitableInfiniteQuery: InfiniteQueryRequest {
  package let initialPageId = 0

  package typealias _Values = (
    values: [Int: String],
    nextPageIds: [Int: Int],
    willWait: Bool,
    continuations: [UnsafeContinuation<Void, Never>],
    onLoading: () -> Void
  )

  package let state = RecursiveLock<_Values>(([:], [:], false, [], {}))

  package init() {}

  package var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  package func waitForLoading() async throws {
    await withUnsafeContinuation { continuation in
      self.state.withLock { $0.continuations.append(continuation) }
    }
    await Task.megaYield()
  }

  package func advance() async {
    await Task.megaYield()
    self.state.withLock {
      for c in $0.continuations {
        c.resume()
      }
      $0.continuations.removeAll()
    }
  }

  package func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    self.state.withLock {
      let id = $0.nextPageIds[page.id] ?? page.id + 1
      return $0.values[id] != nil ? id : nil
    }
  }

  package func pageId(
    before page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    self.state.withLock {
      let id = $0.nextPageIds[page.id] ?? page.id - 1
      return $0.values[id] != nil ? id : nil
    }
  }

  package func fetchPage(
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    self.state.withLock { $0.onLoading() }
    if self.state.withLock({ $0.willWait }) {
      await self.advance()
      try await self.waitForLoading()
    }
    return try self.state.withLock {
      if let value = $0.values[paging.pageId] {
        return value
      }
      throw PageNotFoundError()
    }
  }

  package struct PageNotFoundError: Error {
    package init() {}
  }
}

// MARK: - FailingInfiniteQuery

package final class FailableInfiniteQuery: InfiniteQueryRequest {
  package let initialPageId = 0

  package let state = RecursiveLock<String?>(nil)

  package init() {}

  package var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  package func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    page.id + 1
  }

  package func fetchPage(
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    try self.state.withLock { state in
      if let state {
        return state
      }
      throw SomeError()
    }
  }

  package struct SomeError: Equatable, Error {
    package init() {}
  }
}

// MARK: - EmptyMutation

package struct EmptyMutation: MutationRequest, Hashable {
  package typealias Value = String

  package init() {}

  package func mutate(
    with arguments: String,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    arguments
  }
}

// MARK: - EmptyIntMutation

package struct EmptyIntMutation: MutationRequest, Hashable {
  package typealias Value = Int

  package init() {}

  package func mutate(
    with arguments: Int,
    in context: QueryContext,
    with continuation: QueryContinuation<Int>
  ) async throws -> Int {
    arguments
  }
}

// MARK: - SleepingMutation

package final class SleepingMutation: MutationRequest, @unchecked Sendable {
  package typealias Value = String

  package var didBeginSleeping: (() -> Void)?

  package init() {}

  package var path: QueryPath {
    ["test-sleeping-mutation"]
  }

  package func mutate(
    with arguments: String,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    self.didBeginSleeping?()
    return ""
  }
}

// MARK: - FailableMutation

package final class FailableMutation: MutationRequest {
  package typealias Value = String

  package let state = RecursiveLock<String?>(nil)

  package init() {}

  package var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  package func mutate(
    with arguments: String,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    try self.state.withLock { state in
      if let state {
        return state
      }
      throw MutateError()
    }
  }

  package struct MutateError: Equatable, Error {
    package init() {}
  }
}

// MARK: - WaitableMutation

package final class WaitableMutation: MutationRequest {
  package typealias _Values = (
    willWait: Bool,
    continuations: [String: UnsafeContinuation<Void, any Error>],
    onLoading: [String: @Sendable () -> Void]
  )
  package typealias Value = String
  package typealias Arguments = String

  package let state = RecursiveLock<_Values>((false, [:], [:]))

  package init() {}

  package var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  package func onLoading(for args: String, _ onLoading: @escaping @Sendable () -> Void) {
    self.state.withLock { $0.onLoading[args] = onLoading }
  }

  package func waitForLoading(on args: String) async throws {
    try await withUnsafeThrowingContinuation { continuation in
      self.state.withLock { $0.continuations[args] = continuation }
    }
    await Task.megaYield()
  }

  package func advance(on args: String, with error: (any Error)? = nil) async {
    await Task.megaYield()
    self.state.withLock {
      if let error {
        $0.continuations[args]?.resume(throwing: error)
      } else {
        $0.continuations[args]?.resume()
      }
      $0.continuations.removeValue(forKey: args)
    }
  }

  package func mutate(
    with arguments: String,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    self.state.withLock { $0.onLoading[arguments]?() }
    if self.state.withLock({ $0.willWait }) {
      await self.advance(on: arguments)
      try await self.waitForLoading(on: arguments)
    }
    return arguments
  }
}

// MARK: - ContinuingMutation

package struct ContinuingMutation: MutationRequest, Hashable {
  package typealias Value = String

  package static let values = ["blob", "blob jr", "blob sr"]
  package static let finalValue = "the end"

  package init() {}

  package func mutate(
    with arguments: String,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    for value in Self.values {
      continuation.yield(value)
    }
    return Self.finalValue
  }
}

// MARK: - ContinuingErrorMutation

package struct ContinuingErrorMutation: MutationRequest, Hashable {
  package typealias Value = String

  package static let finalValue = "the end"

  package init() {}

  package func mutate(
    with arguments: String,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    continuation.yield(error: SomeError())
    return Self.finalValue
  }

  package struct SomeError: Equatable, Error {
    package init() {}
  }
}

// MARK: - ContinuingValueThenErrorMutation

package struct ContinuingValueThenErrorMutation: MutationRequest, Hashable {
  package typealias Value = String

  package static let value = "the end"

  package init() {}

  package func mutate(
    with arguments: String,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    continuation.yield(Self.value)
    throw SomeError()
  }

  package struct SomeError: Equatable, Error {
    package init() {}
  }
}
