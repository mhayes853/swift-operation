import Clocks
import ConcurrencyExtras
import QueryCore

// MARK: - TestQuery

struct TestQuery: QueryProtocol, Hashable {
  static let value = 1

  func fetch(in context: QueryContext) async throws -> Int {
    Self.value
  }
}

// MARK: - TestStringQuery

struct TestStringQuery: QueryProtocol, Hashable {
  static let value = "Foo"

  func fetch(in context: QueryContext) async throws -> String {
    Self.value
  }
}

// MARK: - EndlessQuery

final class SleepingQuery: QueryProtocol, @unchecked Sendable {
  let clock: any Clock<Duration>
  let duration: Duration

  var didBeginSleeping: (() -> Void)?

  init(clock: any Clock<Duration>, duration: Duration) {
    self.clock = clock
    self.duration = duration
  }

  var path: QueryPath {
    ["test-sleeping", self.duration]
  }

  func fetch(in context: QueryContext) async throws -> String {
    self.didBeginSleeping?()
    try await self.clock.sleep(for: self.duration)
    return ""
  }
}

// MARK: - FailingQuery

struct FailingQuery: QueryProtocol, Hashable {
  struct SomeError: Equatable, Error {}

  func fetch(in context: QueryContext) async throws -> String {
    throw SomeError()
  }
}

// MARK: - CountingQuery

final actor CountingQuery: QueryProtocol {
  var fetchCount = 0
  private let sleep: @Sendable () async -> Void

  init(sleep: @Sendable @escaping () async -> Void = { await Task.megaYield() }) {
    self.sleep = sleep
  }

  nonisolated var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func fetch(in context: QueryContext) async throws -> Int {
    await self.sleep()
    self.fetchCount += 1
    return self.fetchCount
  }
}

// MARK: - EndlesQuery

struct EndlessQuery: QueryProtocol, Hashable {
  func fetch(in context: QueryContext) async throws -> String {
    try await Task.never()
    return ""
  }
}

// MARK: - FailableQuery

actor FlakeyQuery: QueryProtocol {
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

  func fetch(in context: QueryContext) async throws -> String {
    struct SomeError: Error {}
    guard let result else { throw SomeError() }
    return result
  }
}

// MARK: - PathableQuery

struct PathableQuery: QueryProtocol {
  let value: Int
  let path: QueryPath

  func fetch(in context: QueryContext) async throws -> Int {
    self.value
  }
}

// MARK: - ContextReadingQuery

final actor ContextReadingQuery: QueryProtocol {
  var latestContext: QueryContext?

  nonisolated var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func fetch(in context: QueryContext) async throws -> String {
    self.latestContext = context
    return ""
  }
}

// MARK: - TestInfiniteQuery

struct EmptyInfiniteQuery: InfiniteQueryProtocol {
  let initialPageId: Int
  let path: QueryPath

  func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>
  ) -> Int? {
    nil
  }

  func pageId(
    before page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>
  ) -> Int? {
    nil
  }

  func fetchPage(
    using paging: InfiniteQueryPaging<PageID, PageValue>,
    in context: QueryContext
  ) async throws -> String {
    ""
  }
}

struct EmptyIntInfiniteQuery: InfiniteQueryProtocol {
  let initialPageId: Int
  let path: QueryPath

  func pageId(
    after page: InfiniteQueryPage<Int, Int>,
    using paging: InfiniteQueryPaging<Int, Int>
  ) -> Int? {
    nil
  }

  func pageId(
    before page: InfiniteQueryPage<Int, Int>,
    using paging: InfiniteQueryPaging<Int, Int>
  ) -> Int? {
    nil
  }

  func fetchPage(
    using paging: InfiniteQueryPaging<Int, Int>,
    in context: QueryContext
  ) async throws -> Int {
    0
  }
}

// MARK: - FakeInfiniteQuery

struct FakeInfiniteQuery: QueryProtocol, Hashable {
  typealias State = InfiniteQueryState<Int, String>
  typealias Value = InfiniteQueryValue<Int, String>

  func fetch(in context: QueryContext) async throws -> Value {
    fatalError()
  }
}

// MARK: - TestInfiniteQuery

final class TestInfiniteQuery: InfiniteQueryProtocol {
  let initialPageId = 0

  let state = Lock([Int: String]())

  var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>
  ) -> Int? {
    self.state.withLock { $0[page.id + 1] != nil ? page.id + 1 : nil }
  }

  func pageId(
    before page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>
  ) -> Int? {
    self.state.withLock { $0[page.id - 1] != nil ? page.id - 1 : nil }
  }

  func fetchPage(
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
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

// MARK: - WaitableInfiniteQuery

final class WaitableInfiniteQuery: InfiniteQueryProtocol {
  let initialPageId = 0

  typealias _Values = (
    values: [Int: String],
    nextPageIds: [Int: Int],
    willWait: Bool,
    continuations: [UnsafeContinuation<Void, Never>],
    onLoading: () -> Void
  )

  let state = Lock<_Values>(([:], [:], false, [], {}))

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
    using paging: InfiniteQueryPaging<Int, String>
  ) -> Int? {
    self.state.withLock {
      let id = $0.nextPageIds[page.id] ?? page.id + 1
      return $0.values[id] != nil ? id : nil
    }
  }

  func pageId(
    before page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>
  ) -> Int? {
    self.state.withLock {
      let id = $0.nextPageIds[page.id] ?? page.id - 1
      return $0.values[id] != nil ? id : nil
    }
  }

  func fetchPage(
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
  ) async throws -> String {
    self.state.withLock { $0.onLoading() }
    if self.state.withLock({ $0.willWait }) {
      Task { await self.advance() }
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

final class FailableInfiniteQuery: InfiniteQueryProtocol {
  let initialPageId = 0

  let state = Lock<String?>(nil)

  var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>
  ) -> Int? {
    page.id + 1
  }

  func fetchPage(
    using paging: InfiniteQueryPaging<Int, String>,
    in context: QueryContext
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

struct EmptyMutation: MutationProtocol, Hashable {
  typealias Value = String

  func mutate(with arguments: String, in context: QueryContext) async throws -> String {
    arguments
  }
}

// MARK: - EmptyIntMutation

struct EmptyIntMutation: MutationProtocol, Hashable {
  typealias Value = Int

  func mutate(with arguments: Int, in context: QueryContext) async throws -> Int {
    arguments
  }
}

// MARK: - SleepingMutation

final class SleepingMutation: MutationProtocol, @unchecked Sendable {
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

  func mutate(with arguments: String, in context: QueryContext) async throws -> String {
    self.didBeginSleeping?()
    try await self.clock.sleep(for: self.duration)
    return ""
  }
}

// MARK: - FailableMutation

final class FailableMutation: MutationProtocol {
  typealias Value = String

  let state = Lock<String?>(nil)

  var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func mutate(with arguments: String, in context: QueryContext) async throws -> String {
    try self.state.withLock { state in
      if let state {
        return state
      }
      throw SomeError()
    }
  }

  struct SomeError: Error {}
}

// MARK: - WaitableMutation

final class WaitableMutation: MutationProtocol {
  typealias _Values = (
    willWait: Bool,
    continuations: [String: UnsafeContinuation<Void, any Error>],
    onLoading: [String: @Sendable () -> Void]
  )
  typealias Value = String
  typealias Arguments = String

  let state = Lock<_Values>((false, [:], [:]))

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

  func mutate(with arguments: String, in context: QueryContext) async throws -> String {
    self.state.withLock { $0.onLoading[arguments]?() }
    if self.state.withLock({ $0.willWait }) {
      await self.advance(on: arguments)
      try await self.waitForLoading(on: arguments)
    }
    return arguments
  }
}
