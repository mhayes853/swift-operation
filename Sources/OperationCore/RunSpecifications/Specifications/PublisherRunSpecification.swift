#if canImport(Combine)
  @preconcurrency import Combine

  // MARK: - PublisherObserver

  /// A ``FetchCondition`` that observes the value of a Combine `Publisher`.
  ///
  /// To create this condition, provide a thread-safe `Publisher` that emits a `Bool` and an
  /// initial `Bool` value that is used when your publisher has not emitted a value. If your
  /// publisher is a `CurrentValueSubject`, you can omit the initial value.
  ///
  /// When initialized, this condition will immediately subscribe to your publisher, and will
  /// manually store the latest output. Only 1 subscription is made to your publisher, and changes
  /// from the single subscription are propagated to all subscribers of this condition.
  public final class PublisherRunSpecification<
    P: Publisher & Sendable
  >: OperationRunSpecification, Sendable
  where P.Output == Bool, P.Failure == Never {
    private typealias State = (cancellable: AnyCancellable?, currentValue: Bool)

    private let publisher: P
    private let state: RecursiveLock<State>

    init(publisher: P, initialValue: Bool) {
      self.publisher = publisher
      self.state = RecursiveLock((nil, initialValue))
      self.state.withLock {
        $0.cancellable = publisher.sink { [weak self] value in
          self?.state.withLock { $0.currentValue = value }
        }
      }
    }

    public func isSatisfied(in context: OperationContext) -> Bool {
      self.state.withLock { $0.currentValue }
    }

    public func subscribe(
      in context: OperationContext,
      _ observer: @escaping @Sendable (Bool) -> Void
    ) -> OperationSubscription {
      let cancellable = Lock(self.publisher.sink { observer($0) })
      return OperationSubscription { cancellable.withLock { $0.cancel() } }
    }
  }

  // MARK: - FetchConditionObserver Extensions

  extension OperationRunSpecification {
    /// A ``FetchCondition`` that observes the value of a Combine `Publisher`.
    ///
    /// - Parameters:
    ///   - publisher: The `Publisher` to observe.
    ///   - initialValue: The initial value of this condition that is used while your publisher hasn't emitted anything.
    /// - Returns: A ``PublisherCondition``.
    public static func observing<P: Publisher>(
      publisher: P,
      initialValue: Bool
    ) -> Self where Self == PublisherRunSpecification<P> {
      PublisherRunSpecification(publisher: publisher, initialValue: initialValue)
    }

    /// A ``FetchCondition`` that observes the value of a `CurrentValueSubject`.
    ///
    /// - Parameter subject: The `CurrentValueSubject` to observe.
    /// - Returns: A ``PublisherCondition``.
    public static func observing(
      subject: CurrentValueSubject<Bool, Never>
    ) -> Self where Self == PublisherRunSpecification<CurrentValueSubject<Bool, Never>> {
      PublisherRunSpecification(publisher: subject, initialValue: subject.value)
    }
  }
#endif
