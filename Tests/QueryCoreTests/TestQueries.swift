import ConcurrencyExtras
import QueryCore

// MARK: - TestQuery

struct TestQuery: QueryProtocol, Hashable {
  static let value = 1

  func fetch(in context: QueryContext, currentValue: Int?) async throws -> Int {
    Self.value
  }
}

// MARK: - TestStringQuery

struct TestStringQuery: QueryProtocol, Hashable {
  static let value = "Foo"

  func fetch(in context: QueryContext, currentValue: String?) async throws -> String {
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

  func fetch(in context: QueryContext, currentValue: String?) async throws -> String {
    self.didBeginSleeping?()
    try await self.clock.sleep(for: self.duration)
    return ""
  }
}

// MARK: - FailingQuery

struct FailingQuery: QueryProtocol, Hashable {
  struct SomeError: Equatable, Error {}

  func fetch(in context: QueryContext, currentValue: String?) async throws -> String {
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

  func fetch(in context: QueryContext, currentValue: Int?) async throws -> Int {
    await self.sleep()
    self.fetchCount += 1
    return self.fetchCount
  }
}

// MARK: - EndlesQuery

struct EndlessQuery: QueryProtocol, Hashable {
  func fetch(in context: QueryContext, currentValue: String?) async throws -> String {
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

  func fetch(in context: QueryContext, currentValue: String?) async throws -> String {
    struct SomeError: Error {}
    guard let result else { throw SomeError() }
    return result
  }
}

// MARK: - PathableQuery

struct PathableQuery: QueryProtocol {
  let value: Int
  let path: QueryPath

  func fetch(in context: QueryContext, currentValue: Int?) async throws -> Int {
    self.value
  }
}

// MARK: - ContextReadingQuery

final actor ContextReadingQuery: QueryProtocol {
  var latestContext: QueryContext?

  nonisolated var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func fetch(in context: QueryContext, currentValue: String?) async throws -> String {
    self.latestContext = context
    return ""
  }
}

// MARK: - CurrentValueReadingQuery

final class CurrentValueReadingQuery: QueryProtocol {
  typealias State = (fetchedValue: Int, currentValue: Int?)

  let state = Lock<State>((0, nil))

  var path: QueryPath {
    [ObjectIdentifier(self)]
  }

  func fetch(in context: QueryContext, currentValue: Int?) async throws -> Int {
    self.state.withLock { state in
      state.currentValue = currentValue
      return state.fetchedValue
    }
  }
}
