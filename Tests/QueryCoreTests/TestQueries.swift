import ConcurrencyExtras
import QueryCore

// MARK: - TestQuery

struct TestQuery: QueryProtocol, Hashable {
  static let value = 1

  typealias Value = Int

  func fetch(in context: QueryContext) async throws -> Value {
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

  var id: some Hashable {
    self.duration
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

  nonisolated var id: some Hashable {
    ObjectIdentifier(self)
  }

  func fetch(in context: QueryContext) async throws -> Int {
    await Task.megaYield()
    self.fetchCount += 1
    return self.fetchCount
  }
}

// MARK: - EndlesQuery

struct EndlessQuery: QueryProtocol, Hashable {
  func fetch(in context: QueryCore.QueryContext) async throws -> String {
    try await Task.never()
    return ""
  }
}

// MARK: - FailableQuery

actor FlakeyQuery: QueryProtocol {
  private var result: String?

  nonisolated var id: some Hashable {
    ObjectIdentifier(self)
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
