import QueryCore

// MARK: - TestQuery

struct TestQuery: QueryRequest, Hashable {
  static let value = 1

  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Int>
  ) async throws -> Int {
    Self.value
  }
}

// MARK: - TestStringQuery

struct TestStringQuery: QueryRequest, Hashable {
  static let value = "Foo"

  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    Self.value
  }
}

// MARK: - EndlessQuery

final class SleepingQuery: QueryRequest, @unchecked Sendable {
  var didBeginSleeping: (() -> Void)?

  private let continuation = Lock<UnsafeContinuation<Void, any Error>?>(nil)

  var path: QueryPath {
    ["test-sleeping"]
  }

  func resume() {
    self.continuation.withLock { $0?.resume() }
  }

  func fetch(
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

struct FailingQuery: QueryRequest, Hashable {
  struct SomeError: Equatable, Error {}

  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    throw SomeError()
  }
}

// MARK: - CountingQuery

final actor CountingQuery: QueryRequest {
  var fetchCount = 0
  private var shouldFail = false
  private let sleep: @Sendable () async -> Void

  init(sleep: @Sendable @escaping () async -> Void = { await Task.megaYield() }) {
    self.sleep = sleep
  }

  nonisolated var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func ensureFails() {
    self.shouldFail = true
  }

  func fetch(in context: QueryContext, with continuation: QueryContinuation<Int>) async throws
    -> Int
  {
    await self.sleep()
    self.fetchCount += 1
    if self.shouldFail {
      throw SomeError()
    }
    return self.fetchCount
  }

  struct SomeError: Equatable, Error {}
}

// MARK: - EndlesQuery

struct EndlessQuery: QueryRequest, Hashable {
  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    try await Task.never()
    return ""
  }
}

// MARK: - NonCancellingEndlessQuery

struct NonCancellingEndlessQuery: QueryRequest, Hashable {
  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    try? await Task.never()
    continuation.yield("blob")
    return ""
  }
}

// MARK: - FailableQuery

actor FlakeyQuery: QueryRequest {
  private var result: String?

  nonisolated var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func ensureSuccess(result: String) {
    self.result = result
  }

  func ensureFailure() {
    self.result = nil
  }

  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    struct SomeError: Error {}
    guard let result else { throw SomeError() }
    return result
  }
}

// MARK: - PathableQuery

struct PathableQuery: QueryRequest {
  let value: Int
  let path: QueryPath

  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Int>
  ) async throws -> Int {
    self.value
  }
}

// MARK: - SucceedOnNthRefetchQuery

struct SucceedOnNthRefetchQuery: QueryRequest, Hashable {
  static let value = "refetch success"

  let index: Int

  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    if context.queryRetryIndex < self.index {
      throw SomeError()
    }
    return Self.value
  }

  struct SomeError: Error {}
}

// MARK: - ContextReadingQuery

final actor ContextReadingQuery: QueryRequest {
  var latestContext: QueryContext?

  nonisolated var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    self.latestContext = context
    return ""
  }
}

// MARK: - ContinuingQuery

struct ContinuingQuery: QueryRequest, Hashable {
  static let values = ["blob", "blob jr", "blob sr"]
  static let finalValue = "the end"

  func fetch(
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

struct ContinuingErrorQuery: QueryRequest, Hashable {
  static let finalValue = "the end"

  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    continuation.yield(error: SomeError())
    return Self.finalValue
  }

  struct SomeError: Equatable, Error {}
}

// MARK: - ContinuingValueThenErrorQuery

struct ContinuingValueThenErrorQuery: QueryRequest, Hashable {
  static let value = "the end"

  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    continuation.yield(Self.value)
    throw SomeError()
  }

  struct SomeError: Equatable, Error {}
}

// MARK: - TestInfiniteQuery

struct EmptyInfiniteQuery: InfiniteQueryRequest {
  let initialPageId: Int
  let path: QueryPath

  func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    nil
  }

  func pageId(
    before page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    nil
  }

  func fetchPage(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    ""
  }
}

struct EmptyIntInfiniteQuery: InfiniteQueryRequest {
  let initialPageId: Int
  let path: QueryPath

  func pageId(
    after page: InfiniteQueryPage<Int, Int>,
    using paging: InfiniteQueryPaging<Int, Int>,
    in context: QueryContext
  ) -> Int? {
    nil
  }

  func pageId(
    before page: InfiniteQueryPage<Int, Int>,
    using paging: InfiniteQueryPaging<Int, Int>,
    in context: QueryContext
  ) -> Int? {
    nil
  }

  func fetchPage(
    using paging: InfiniteQueryPaging<Int, Int>,
    in context: QueryContext,
    with continuation: QueryContinuation<Int>
  ) async throws -> Int {
    0
  }
}

// MARK: - FakeInfiniteQuery

struct FakeInfiniteQuery: QueryRequest, Hashable {
  typealias State = InfiniteQueryState<Int, String>
  typealias Value = InfiniteQueryValue<Int, String>

  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value {
    fatalError()
  }
}

// MARK: - TestInfiniteQuery

final class TestInfiniteQuery: InfiniteQueryRequest {
  let initialPageId = 0

  let state = RecursiveLock([Int: String]())

  var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    self.state.withLock { $0[page.id + 1] != nil ? page.id + 1 : nil }
  }

  func pageId(
    before page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    self.state.withLock { $0[page.id - 1] != nil ? page.id - 1 : nil }
  }

  func fetchPage(
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

  struct PageNotFoundError: Error {}
}

// MARK: - CountingInfiniteQuery

final actor CountingInfiniteQuery: InfiniteQueryRequest {
  let initialPageId = 0

  var fetchCount = 0

  func resetCount() {
    self.fetchCount = 0
  }

  nonisolated var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  nonisolated func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    page.id + 1
  }

  nonisolated func pageId(
    before page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    page.id - 1
  }

  func fetchPage(
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

final class FlakeyInfiniteQuery: InfiniteQueryRequest {
  typealias PageValue = String
  typealias PageID = Int

  typealias Values = (failOnPageId: Int, fetchCount: Int)

  let values = RecursiveLock<Values>((failOnPageId: 0, fetchCount: 0))

  let initialPageId = 0

  var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func pageId(
    after page: InfiniteQueryPage<PageID, PageValue>,
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) -> PageID? {
    page.id + 1
  }

  func fetchPage(
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

  struct SomeError: Equatable, Error {}
}

// MARK: - TestYieldableInfiniteQuery

final class TestYieldableInfiniteQuery: InfiniteQueryRequest {
  static func finalValue(for id: PageID) -> String {
    "page final value \(id)"
  }

  static func finalPage(for id: PageID) -> InfiniteQueryPage<Int, String> {
    InfiniteQueryPage(id: id, value: finalValue(for: id))
  }

  let initialPageId = 0
  let shouldThrow: Bool

  init(shouldThrow: Bool = false) {
    self.shouldThrow = shouldThrow
  }

  let state = RecursiveLock([Int: [Result<PageValue, any Error>]]())

  var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    page.id + 1
  }

  func pageId(
    before page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    page.id - 1
  }

  func fetchPage(
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

  struct SomeError: Equatable, Error {}
}

// MARK: - WaitableInfiniteQuery

final class WaitableInfiniteQuery: InfiniteQueryRequest {
  let initialPageId = 0

  typealias _Values = (
    values: [Int: String],
    nextPageIds: [Int: Int],
    willWait: Bool,
    continuations: [UnsafeContinuation<Void, Never>],
    onLoading: () -> Void
  )

  let state = RecursiveLock<_Values>(([:], [:], false, [], {}))

  var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func waitForLoading() async throws {
    await withUnsafeContinuation { continuation in
      self.state.withLock { $0.continuations.append(continuation) }
    }
    await Task.megaYield()
  }

  func advance() async {
    await Task.megaYield()
    self.state.withLock {
      for c in $0.continuations {
        c.resume()
      }
      $0.continuations.removeAll()
    }
  }

  func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    self.state.withLock {
      let id = $0.nextPageIds[page.id] ?? page.id + 1
      return $0.values[id] != nil ? id : nil
    }
  }

  func pageId(
    before page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    self.state.withLock {
      let id = $0.nextPageIds[page.id] ?? page.id - 1
      return $0.values[id] != nil ? id : nil
    }
  }

  func fetchPage(
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

  struct PageNotFoundError: Error {}
}

// MARK: - FailingInfiniteQuery

final class FailableInfiniteQuery: InfiniteQueryRequest {
  let initialPageId = 0

  let state = RecursiveLock<String?>(nil)

  var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) -> Int? {
    page.id + 1
  }

  func fetchPage(
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

  struct SomeError: Error {}
}

// MARK: - EmptyMutation

struct EmptyMutation: MutationRequest, Hashable {
  typealias Value = String

  func mutate(
    with arguments: String,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    arguments
  }
}

// MARK: - EmptyIntMutation

struct EmptyIntMutation: MutationRequest, Hashable {
  typealias Value = Int

  func mutate(
    with arguments: Int,
    in context: QueryContext,
    with continuation: QueryContinuation<Int>
  ) async throws -> Int {
    arguments
  }
}

// MARK: - SleepingMutation

final class SleepingMutation: MutationRequest, @unchecked Sendable {
  typealias Value = String

  let clock: any Clock<Duration>
  let duration: Duration

  var didBeginSleeping: (() -> Void)?

  init(clock: any Clock<Duration>, duration: Duration) {
    self.clock = clock
    self.duration = duration
  }

  var path: QueryPath {
    ["test-sleeping-mutation", self.duration]
  }

  func mutate(
    with arguments: String,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    self.didBeginSleeping?()
    try await self.clock.sleep(for: self.duration)
    return ""
  }
}

// MARK: - FailableMutation

final class FailableMutation: MutationRequest {
  typealias Value = String

  let state = RecursiveLock<String?>(nil)

  var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func mutate(
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

  struct MutateError: Equatable, Error {}
}

// MARK: - WaitableMutation

final class WaitableMutation: MutationRequest {
  typealias _Values = (
    willWait: Bool,
    continuations: [String: UnsafeContinuation<Void, any Error>],
    onLoading: [String: @Sendable () -> Void]
  )
  typealias Value = String
  typealias Arguments = String

  let state = RecursiveLock<_Values>((false, [:], [:]))

  var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func onLoading(for args: String, _ onLoading: @escaping @Sendable () -> Void) {
    self.state.withLock { $0.onLoading[args] = onLoading }
  }

  func waitForLoading(on args: String) async throws {
    try await withUnsafeThrowingContinuation { continuation in
      self.state.withLock { $0.continuations[args] = continuation }
    }
    await Task.megaYield()
  }

  func advance(on args: String, with error: (any Error)? = nil) async {
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

  func mutate(
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

struct ContinuingMutation: MutationRequest, Hashable {
  typealias Value = String

  static let values = ["blob", "blob jr", "blob sr"]
  static let finalValue = "the end"

  func mutate(
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

struct ContinuingErrorMutation: MutationRequest, Hashable {
  typealias Value = String

  static let finalValue = "the end"

  func mutate(
    with arguments: String,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    continuation.yield(error: SomeError())
    return Self.finalValue
  }

  struct SomeError: Equatable, Error {}
}

// MARK: - ContinuingValueThenErrorMutation

struct ContinuingValueThenErrorMutation: MutationRequest, Hashable {
  typealias Value = String

  static let value = "the end"

  func mutate(
    with arguments: String,
    in context: QueryContext,
    with continuation: QueryContinuation<String>
  ) async throws -> String {
    continuation.yield(Self.value)
    throw SomeError()
  }

  struct SomeError: Equatable, Error {}
}
