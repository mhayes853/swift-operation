#if canImport(Combine)
  @preconcurrency import Combine

  // MARK: - PublisherObserver

  /// An ``OperationRunSpecification`` that observes the value of a Combine `Publisher`.
  ///
  /// To create this specification, provide a thread-safe `Publisher` that emits a `Bool` and an
  /// initial `Bool` value that is used when your publisher has not emitted a value. If your
  /// publisher is a `CurrentValueSubject`, you can omit the initial value.
  ///
  /// When initialized, this specification will immediately subscribe to your publisher, and will
  /// manually store the latest output. Only 1 subscription is made to your publisher, and changes
  /// from the single subscription are broadcasted to all subscribers of this specification.
  public final class PublisherRunSpecification<
    P: Publisher & Sendable
  >: OperationRunSpecification, Sendable
  where P.Output == Bool, P.Failure == Never {
    private struct State {
      var cancellable: AnyCancellable?
      var currentValue: Bool
    }
    private typealias Handler = @Sendable () -> Void

    private let publisher: P
    private let state: RecursiveLock<State>
    private let subscriptions = OperationSubscriptions<Handler>()

    public init(_ publisher: P, initialValue: Bool) {
      self.publisher = publisher
      self.state = RecursiveLock(State(cancellable: nil, currentValue: initialValue))
      self.state.withLock {
        $0.cancellable = publisher.sink { [weak self] value in
          self?.state.withLock { $0.currentValue = value }
          self?.subscriptions.forEach { $0() }
        }
      }
    }

    public convenience init(_ subject: P) where P == CurrentValueSubject<Bool, Never> {
      self.init(subject, initialValue: subject.value)
    }

    public func isSatisfied(in context: OperationContext) -> Bool {
      self.state.withLock { $0.currentValue }
    }

    public func subscribe(
      in context: OperationContext,
      onChange: @escaping @Sendable () -> Void
    ) -> OperationSubscription {
      self.subscriptions.add(handler: onChange).subscription
    }
  }

  // MARK: - FetchConditionObserver Extensions

  extension OperationRunSpecification {
    /// An ``OperationRunSpecification`` that observes the value of a Combine `Publisher`.
    ///
    /// - Parameters:
    ///   - publisher: The `Publisher` to observe.
    ///   - initialValue: The initial value of this condition that is used while your publisher hasn't emitted anything.
    /// - Returns: A ``PublisherRunSpecification``.
    public static func observing<P: Publisher>(
      publisher: P,
      initialValue: Bool
    ) -> Self where Self == PublisherRunSpecification<P> {
      PublisherRunSpecification(publisher, initialValue: initialValue)
    }

    /// An ``OperationRunSpecification`` that observes the value of a Combine `Publisher`.
    ///
    /// - Parameter subject: The `CurrentValueSubject` to observe.
    /// - Returns: A ``PublisherRunSpecification``.
    public static func observing(
      subject: CurrentValueSubject<Bool, Never>
    ) -> Self where Self == PublisherRunSpecification<CurrentValueSubject<Bool, Never>> {
      PublisherRunSpecification(subject)
    }
  }
#endif
