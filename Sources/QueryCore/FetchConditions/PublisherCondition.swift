#if canImport(Combine)
  @preconcurrency import Combine

  // MARK: - PublisherObserver

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
      let cancellable = RecursiveLock(self.publisher.sink { observer($0) })
      return QuerySubscription { cancellable.withLock { $0.cancel() } }
    }
  }

  // MARK: - FetchConditionObserver Extensions

  extension FetchCondition {
    public static func observing<P: Publisher>(
      publisher: P,
      initialValue: Bool
    ) -> Self where Self == PublisherCondition<P> {
      PublisherCondition(publisher: publisher, initialValue: initialValue)
    }

    public static func observing(
      subject: CurrentValueSubject<Bool, Never>
    ) -> Self where Self == PublisherCondition<CurrentValueSubject<Bool, Never>> {
      PublisherCondition(publisher: subject, initialValue: subject.value)
    }
  }
#endif
