import QueryCore

final class TestCondition: FetchCondition {
  private typealias Handler = @Sendable (Bool) -> Void

  private let value = RecursiveLock(false)
  private let subscribers = QuerySubscriptions<Handler>()

  var subscriberCount: Int {
    self.subscribers.count
  }

  func isSatisfied(in context: QueryContext) -> Bool {
    self.value.withLock { $0 }
  }

  func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    self.subscribers.add(handler: observer).0
  }

  func send(_ value: Bool) {
    self.value.withLock {
      $0 = value
      self.subscribers.forEach { $0(value) }
    }
  }
}
