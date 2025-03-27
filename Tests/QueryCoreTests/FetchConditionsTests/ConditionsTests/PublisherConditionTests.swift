#if canImport(Combine)
  import CustomDump
  import QueryCore
  import Testing
  @preconcurrency import Combine

  @Suite("PublisherCondition tests")
  struct PublisherConditionTests {
    @Test("Observes Publisher Value")
    func observePublisherValue() {
      let subject = PassthroughSubject<Bool, Never>()
      let observer: some FetchCondition = .observing(
        publisher: subject,
        initialValue: true
      )
      let values = RecursiveLock([Bool]())
      let subscription = observer.subscribe(in: QueryContext()) { value in
        values.withLock { $0.append(value) }
      }

      subject.send(false)
      subject.send(true)

      values.withLock { expectNoDifference($0, [false, true]) }
      subscription.cancel()
    }

    @Test("Is Publisher Value In Context")
    func isPublisherValueInContext() {
      let context = QueryContext()
      let subject = PassthroughSubject<Bool, Never>()
      let observer: some FetchCondition = .observing(
        publisher: subject,
        initialValue: true
      )
      expectNoDifference(observer.isSatisfied(in: context), true)

      subject.send(false)
      expectNoDifference(observer.isSatisfied(in: context), false)

      subject.send(true)
      expectNoDifference(observer.isSatisfied(in: context), true)
    }

    @Test("Uses Initial Value From CurrentValueSubject")
    func usesInitialValueFromCurrentValueSubject() {
      let context = QueryContext()
      let subject = CurrentValueSubject<Bool, Never>(true)
      let observer: some FetchCondition = .observing(subject: subject)
      expectNoDifference(observer.isSatisfied(in: context), true)

      subject.send(false)
      expectNoDifference(observer.isSatisfied(in: context), false)
    }

  }
#endif
