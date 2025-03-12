import CustomDump
import QueryCore
import Testing

@Suite("OrCondition tests")
struct OrConditionTests {
  @Test("Is True When Both Conditions Are True")
  func trueWhenBothTrue() {
    let c1: some FetchCondition = .always(true)
    let c2: some FetchCondition = .always(true)
    expectNoDifference((c1 || c2).isSatisfied(in: QueryContext()), true)
  }

  @Test("Is True When Right Condition Is False")
  func trueWhenRightFalse() {
    let c1: some FetchCondition = .always(true)
    let c2: some FetchCondition = .always(false)
    expectNoDifference((c1 || c2).isSatisfied(in: QueryContext()), true)
  }

  @Test("Is True When Left Condition Is False")
  func trueWhenLeftFalse() {
    let c1: some FetchCondition = .always(false)
    let c2: some FetchCondition = .always(true)
    expectNoDifference((c1 || c2).isSatisfied(in: QueryContext()), true)
  }

  @Test("Is False When Both Conditions Are False")
  func falseWhenBothFalse() {
    let c1: some FetchCondition = .always(false)
    let c2: some FetchCondition = .always(false)
    expectNoDifference((c1 || c2).isSatisfied(in: QueryContext()), false)
  }

  @Test("||s Subscribed Values")
  func orsSubscribedValues() {
    let c1 = TestCondition()
    let c2 = TestCondition()
    let values = Lock([Bool]())
    let subscription = (c1 || c2)
      .subscribe(in: QueryContext()) { value in
        values.withLock { $0.append(value) }
      }

    c1.send(true)
    c2.send(true)
    c1.send(false)
    c2.send(false)
    c1.send(true)
    c1.send(false)
    c2.send(true)

    values.withLock { expectNoDifference($0, [true, true, true, false, true, false, true]) }

    subscription.cancel()
  }
}
