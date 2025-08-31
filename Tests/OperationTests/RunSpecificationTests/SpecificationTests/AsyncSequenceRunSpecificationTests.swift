import CustomDump
import Operation
import Testing

@Suite("AsyncSequenceRunSpecification tests")
struct AsyncSequenceRunSpecificationTests {
  @Test("Observes Publisher Value")
  @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 18.0, visionOS 2.0, *)
  func observeSequenceValue() async {
    let (stream, continuation) = AsyncStream<Bool>.makeStream()
    let (substream, subcontinuation) = AsyncStream<Void>.makeStream()
    let observer: some OperationRunSpecification & Sendable = .observing(
      sequence: stream,
      initialValue: true
    )
    let values = Lock([Bool]())
    let subscription = observer.subscribe(in: OperationContext()) {
      values.withLock {
        $0.append(observer.isSatisfied(in: OperationContext()))
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
  @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 18.0, visionOS 2.0, *)
  func isSequenceValueInContext() async {
    let context = OperationContext()
    let (stream, continuation) = AsyncStream<Bool>.makeStream()
    let (substream, subcontinuation) = AsyncStream<Void>.makeStream()
    let observer: some OperationRunSpecification & Sendable = .observing(
      sequence: stream,
      initialValue: true
    )
    let subscription = observer.subscribe(in: OperationContext()) {
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
