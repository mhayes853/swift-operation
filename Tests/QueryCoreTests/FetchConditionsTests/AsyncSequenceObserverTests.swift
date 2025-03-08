import ConcurrencyExtras
import CustomDump
import QueryCore
import Testing

@Suite("PublisherObserver tests")
struct AsyncSequenceObserverTests {
  @Test("Observes Publisher Value")
  func observeSequenceValue() async {
    let (stream, continuation) = AsyncStream<Bool>.makeStream()
    let observer: some FetchConditionObserver = .observing(
      sequence: stream,
      initialValue: true
    )
    let values = Lock([Bool]())
    let subscription = observer.subscribe(in: QueryContext()) { value in
      values.withLock { $0.append(value) }
    }

    continuation.yield(false)
    await Task.megaYield()

    continuation.yield(true)
    await Task.megaYield()

    values.withLock { expectNoDifference($0, [false, true]) }
    subscription.cancel()
  }

  @Test("Is Sequence Value In Context")
  func isSequenceValueInContext() async {
    let context = QueryContext()
    let (stream, continuation) = AsyncStream<Bool>.makeStream()
    let observer: some FetchConditionObserver = .observing(
      sequence: stream,
      initialValue: true
    )
    expectNoDifference(observer.isSatisfied(in: context), true)

    continuation.yield(false)
    await Task.megaYield()
    expectNoDifference(observer.isSatisfied(in: context), false)

    continuation.yield(true)
    await Task.megaYield()
    expectNoDifference(observer.isSatisfied(in: context), true)
  }
}
