#if canImport(Combine)
  import CustomDump
  import Operation
  import Testing
  @preconcurrency import Combine

  @Suite("PublisherRunSpecification tests")
  struct PublisherRunSpecificationTests {
    @Test("Observes Publisher Value")
    func observePublisherValue() {
      let subject = PassthroughSubject<Bool, Never>()
      let observer: some OperationRunSpecification = .observing(
        publisher: subject,
        initialValue: true
      )
      let values = RecursiveLock([Bool]())
      let subscription = observer.subscribe(in: OperationContext()) { value in
        values.withLock { $0.append(value) }
      }

      subject.send(false)
      subject.send(true)

      values.withLock { expectNoDifference($0, [false, true]) }
      subscription.cancel()
    }

    @Test("Is Publisher Value In Context")
    func isPublisherValueInContext() {
      let context = OperationContext()
      let subject = PassthroughSubject<Bool, Never>()
      let observer: some OperationRunSpecification = .observing(
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
      let context = OperationContext()
      let subject = CurrentValueSubject<Bool, Never>(true)
      let observer: some OperationRunSpecification = .observing(subject: subject)
      expectNoDifference(observer.isSatisfied(in: context), true)

      subject.send(false)
      expectNoDifference(observer.isSatisfied(in: context), false)
    }

  }
#endif
