/// An ``OperationRunSpecification`` that observes an `AsyncSequence`.
///
/// To create this specification, provide a Sendable `AsyncSequence` and an initial boolean value
/// that is used for when your sequence hasn't emitted an element.
///
/// When initialized, this specification will immediately begin iterating over your sequence, and
/// will store the iterated value internally. Additionally, each iteration will broadcast its
/// result to all subscribers of this specification.
///
/// When this specification is deallocated, iteration stops on your sequence provided that your
/// sequence opts into cooperative cancellation.
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
public final class AsyncSequenceRunSpecification<
  S: AsyncSequence & Sendable
>: OperationRunSpecification, Sendable
where S.Element == Bool, S.Failure == Never {
  private typealias State = (task: Task<Void, Never>?, currentValue: Bool)
  private typealias Handler = @Sendable () -> Void

  private let subscriptions = OperationSubscriptions<Handler>()
  private let state: RecursiveLock<State>

  public init(sequence: S, initialValue: Bool) {
    self.state = RecursiveLock((nil, initialValue))
    self.state.withLock {
      $0.task = Task { [weak self] in
        for await value in sequence {
          guard let self else { break }
          self.state
            .withLock {
              $0.currentValue = value
              self.subscriptions.forEach { $0() }
            }
        }
      }
    }
  }

  deinit {
    self.state.withLock { $0.task?.cancel() }
  }

  public func isSatisfied(in context: OperationContext) -> Bool {
    self.state.withLock { $0.currentValue }
  }

  public func subscribe(
    in context: OperationContext,
    onChange: @escaping @Sendable () -> Void
  ) -> OperationSubscription {
    self.subscriptions.add(handler: onChange).0
  }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension OperationRunSpecification {
  /// An ``OperationRunSpecification`` that observes an `AsyncSequence`.
  ///
  /// - Parameters:
  ///   - sequence: The sequence to observe.
  ///   - initialValue: The intial boolean value that is used while your sequence hasn't emitted anything.
  /// - Returns: An ``AsyncSequenceRunSpecification``.
  public static func observing<S>(
    sequence: S,
    initialValue: Bool
  ) -> Self where Self == AsyncSequenceRunSpecification<S> {
    Self(sequence: sequence, initialValue: initialValue)
  }
}
