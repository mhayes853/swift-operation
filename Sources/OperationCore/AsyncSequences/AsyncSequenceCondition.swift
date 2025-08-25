/// A ``FetchCondition`` that observes an `AsyncSequence`.
///
/// To create this condition, provide a Sendable `AsyncSequence` and initial `Bool` value that is
/// used for when your sequence hasn't emitted an element.
///
/// When initialized, this condition will immediately begin iterating over your sequence, and will
/// store the iterated value internally. Additionally, each iteration will broadcast its result to
/// all subscribers of this condition.
///
/// When this condition is deallocated, iteration stops on your sequence provided that you opt into
/// cooperative cancellation.
public final class AsyncSequenceCondition<S: AsyncSequence & Sendable>: Sendable
where S.Element == Bool {
  private typealias State = (task: Task<Void, any Error>?, currentValue: Bool)
  private typealias Handler = @Sendable (Bool) -> Void

  private let subscriptions = QuerySubscriptions<Handler>()
  private let state: RecursiveLock<State>

  init(sequence: S, initialValue: Bool) {
    self.state = RecursiveLock((nil, initialValue))
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
  /// A ``FetchCondition`` that observes an `AsyncSequence`.
  ///
  /// - Parameters:
  ///   - sequence: The sequence to observe.
  ///   - initialValue: The intial boolean value that is used while your sequence hasn't emitted anything.
  /// - Returns: A ``AsyncSequenceCondition``.
  public static func observing<S: AsyncSequence>(
    sequence: S,
    initialValue: Bool
  ) -> Self where Self == AsyncSequenceCondition<S> {
    Self(sequence: sequence, initialValue: initialValue)
  }
}
