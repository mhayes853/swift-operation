public final class AsyncSequenceCondition<S: AsyncSequence & Sendable>: Sendable
where S.Element == Bool {
  private typealias State = (task: Task<Void, any Error>?, currentValue: Bool)
  private typealias Handler = @Sendable (Bool) -> Void

  private let subscriptions = QuerySubscriptions<Handler>()
  private let state: Lock<State>

  init(sequence: S, initialValue: Bool) {
    self.state = Lock((nil, initialValue))
    self.state.withLock {
      $0.task = Task { [weak self] in
        for try await value in sequence {
          self?.state.withLock { $0.currentValue = value }
          self?.subscriptions.forEach { $0(value) }
        }
      }
    }
  }

  deinit {
    self.state.withLock { $0.task?.cancel() }
  }
}

extension AsyncSequenceCondition: FetchCondition {
  public func isSatisfied(in context: QueryContext) -> Bool {
    self.state.withLock { $0.currentValue }
  }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    self.subscriptions.add(handler: observer).0
  }
}

extension FetchCondition {
  public static func observing<S: AsyncSequence>(
    sequence: S,
    initialValue: Bool
  ) -> Self where Self == AsyncSequenceCondition<S> {
    Self(sequence: sequence, initialValue: initialValue)
  }
}
