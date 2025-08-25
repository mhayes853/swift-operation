import CustomDump
import Operation
import Testing

@Suite("AsyncSequenceCondition tests")
struct AsyncSequenceConditionTests {
  @Test("Observes Publisher Value")
  func observeSequenceValue() async {
    let (stream, continuation) = AsyncStream<Bool>.makeStream()
    let (substream, subcontinuation) = AsyncStream<Void>.makeStream()
    let observer: some FetchCondition = .observing(
      sequence: stream,
      initialValue: true
    )
    let values = Lock([Bool]())
    let subscription = observer.subscribe(in: QueryContext()) { value in
      values.withLock {
        $0.append(value)
        subcontinuation.yield()
      }
    }

    var subIter = substream.makeAsyncIterator()

    continuation.yield(false)
    await subIter.next()

    continuation.yield(true)
    await subIter.next()

    values.withLock { expectNoDifference($0, [false, true]) }
    subscription.cancel()
  }

  @Test("Is Sequence Value In Context")
  func isSequenceValueInContext() async {
    let context = QueryContext()
    let (stream, continuation) = AsyncStream<Bool>.makeStream()
    let (substream, subcontinuation) = AsyncStream<Void>.makeStream()
    let observer: some FetchCondition = .observing(
      sequence: stream,
      initialValue: true
    )
    let subscription = observer.subscribe(in: QueryContext()) { _ in
      subcontinuation.yield()
    }
    expectNoDifference(observer.isSatisfied(in: context), true)

    var subIter = substream.makeAsyncIterator()

    continuation.yield(false)
    await subIter.next()
    expectNoDifference(observer.isSatisfied(in: context), false)

    continuation.yield(true)
    await subIter.next()
    expectNoDifference(observer.isSatisfied(in: context), true)

    subscription.cancel()
  }
}
