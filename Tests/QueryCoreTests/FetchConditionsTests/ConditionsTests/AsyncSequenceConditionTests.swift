import CustomDump
import QueryCore
import Testing

@Suite("AsyncSequenceCondition tests")
struct AsyncSequenceConditionTests {
  @Test("Observes Publisher Value")
  func observeSequenceValue() async {
    let (stream, continuation) = AsyncStream<Bool>.makeStream()
    let observer: some FetchCondition = .observing(
      sequence: stream,
      initialValue: true
    )
    let values = RecursiveLock([Bool]())
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
    let observer: some FetchCondition = .observing(
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
