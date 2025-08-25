import Operation

final class TestMemoryPressureSource: MemoryPressureSource, Sendable {
  typealias Handler = @Sendable (MemoryPressure) -> Void

  private let subscribers = QuerySubscriptions<Handler>()

  func subscribe(with handler: @escaping Handler) -> QuerySubscription {
    return self.subscribers.add(handler: handler).subscription
  }

  func send(pressure: MemoryPressure) {
    self.subscribers.forEach { $0(pressure) }
  }
}
