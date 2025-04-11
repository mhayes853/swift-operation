#if canImport(Combine)
  @preconcurrency import Combine

  // MARK: - PublisherObserver

  /// A ``FetchCondition`` that observes the value of a Combine `Publisher`.
  ///
  /// To create this condition, provide a thread-safe `Publisher` that emits a `Bool` and an
  /// initial `Bool` value. If your publisher is a `CurrentValueSubject`, you can omit the initial
  /// value.
  ///
  /// When initialized, this condition will immediately subscribe to your publisher, and will
  /// manually store the latest output. Only 1 subscription is made to your publisher, and changes
  /// from the single subscription are propagated to all subscribers of this condition.
  public final class PublisherCondition<P: Publisher & Sendable>
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
  }

  // MARK: - FetchConditionObserver Conformance

  extension PublisherCondition: FetchCondition {
    public func isSatisfied(in context: QueryContext) -> Bool {
      self.state.withLock { $0.currentValue }
    }

    public func subscribe(
      in context: QueryContext,
      _ observer: @escaping @Sendable (Bool) -> Void
    ) -> QuerySubscription {
      let cancellable = Lock(self.publisher.sink { observer($0) })
      return QuerySubscription { cancellable.withLock { $0.cancel() } }
    }
  }

  // MARK: - FetchConditionObserver Extensions

extension FetchCondition {
    /// A ``FetchCondition`` that observes the value of a Combine `Publisher`.
    ///
    /// - Parameters:
    ///   - publisher: The `Publisher` to observe.
    ///   - initialValue: The initial value of this condition.
    /// - Returns: A ``PublisherCondition``.
    public static func observing<P: Publisher>(
      publisher: P,
      initialValue: Bool
    ) -> Self where Self == PublisherCondition<P> {
      PublisherCondition(publisher: publisher, initialValue: initialValue)
    }

    /// A ``FetchCondition`` that observes the value of a `CurrentValueSubject`.
    ///
    /// - Parameter subject: The `CurrentValueSubject` to observe.
    /// - Returns: A ``PublisherCondition``.
    public static func observing(
      subject: CurrentValueSubject<Bool, Never>
    ) -> Self where Self == PublisherCondition<CurrentValueSubject<Bool, Never>> {
      PublisherCondition(publisher: subject, initialValue: subject.value)
    }
  }
#endif
