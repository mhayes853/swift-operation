import Operation

final class TestRunSpecification: OperationRunSpecification, Sendable {
  private typealias Handler = @Sendable () -> Void

  private let value = RecursiveLock(false)
  private let subscribers = OperationSubscriptions<Handler>()

  var subscriberCount: Int {
    self.subscribers.count
  }

  func isSatisfied(in context: OperationContext) -> Bool {
    self.value.withLock { $0 }
  }

  func subscribe(
    in context: OperationContext,
    onChange: @escaping @Sendable () -> Void
  ) -> OperationSubscription {
    self.subscribers.add(handler: onChange).0
  }

  func send(_ value: Bool) {
    self.value.withLock {
      $0 = value
      self.subscribers.forEach { $0() }
    }
  }
}
