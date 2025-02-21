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
