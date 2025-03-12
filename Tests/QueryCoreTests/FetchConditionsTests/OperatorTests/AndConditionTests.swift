import CustomDump
import QueryCore
import Testing

@Suite("AndCondition tests")
struct AndConditionTests {
  @Test("Is True When Both Conditions Are True")
  func trueWhenBothTrue() {
    let c1: some FetchCondition = .always(true)
    let c2: some FetchCondition = .always(true)
    expectNoDifference((c1 && c2).isSatisfied(in: QueryContext()), true)
  }

  @Test("Is False When Right Condition Is False")
  func falseWhenRightFalse() {
    let c1: some FetchCondition = .always(true)
    let c2: some FetchCondition = .always(false)
    expectNoDifference((c1 && c2).isSatisfied(in: QueryContext()), false)
  }

  @Test("Is False When Left Condition Is False")
  func falseWhenLeftFalse() {
    let c1: some FetchCondition = .always(false)
    let c2: some FetchCondition = .always(false)
    expectNoDifference((c1 && c2).isSatisfied(in: QueryContext()), false)
  }

  @Test("Is False When Both Conditions Are False")
  func falseWhenBothFalse() {
    let c1: some FetchCondition = .always(false)
    let c2: some FetchCondition = .always(false)
    expectNoDifference((c1 && c2).isSatisfied(in: QueryContext()), false)
  }

  @Test("&&s Subscribed Values")
  func andsSubscribedValues() {
    let c1 = TestCondition()
    let c2 = TestCondition()
    let values = Lock([Bool]())
    let subscription = (c1 && c2)
      .subscribe(in: QueryContext()) { value in
        values.withLock { $0.append(value) }
      }

    c1.send(true)
    c2.send(true)
    c1.send(false)
    c1.send(true)
    c2.send(false)
    c2.send(true)

    values.withLock { expectNoDifference($0, [false, true, false, true, false, true]) }

    subscription.cancel()
  }
}
