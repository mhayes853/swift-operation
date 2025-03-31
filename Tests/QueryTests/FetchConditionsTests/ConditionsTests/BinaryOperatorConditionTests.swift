import CustomDump
import Query
import Testing

@Suite("BinaryOperatorCondition tests")
struct BinaryOperatorConditionTests {
  @Test("|| Is True When Both Conditions Are True")
  func orTrueWhenBothTrue() {
    let c1: some FetchCondition = .always(true)
    let c2: some FetchCondition = .always(true)
    expectNoDifference((c1 || c2).isSatisfied(in: QueryContext()), true)
  }

  @Test("|| Is True When Right Condition Is False")
  func orTrueWhenRightFalse() {
    let c1: some FetchCondition = .always(true)
    let c2: some FetchCondition = .always(false)
    expectNoDifference((c1 || c2).isSatisfied(in: QueryContext()), true)
  }

  @Test("|| Is True When Left Condition Is False")
  func orTrueWhenLeftFalse() {
    let c1: some FetchCondition = .always(false)
    let c2: some FetchCondition = .always(true)
    expectNoDifference((c1 || c2).isSatisfied(in: QueryContext()), true)
  }

  @Test("|| Is False When Both Conditions Are False")
  func orFalseWhenBothFalse() {
    let c1: some FetchCondition = .always(false)
    let c2: some FetchCondition = .always(false)
    expectNoDifference((c1 || c2).isSatisfied(in: QueryContext()), false)
  }

  @Test("||s Subscribed Values")
  func orsSubscribedValues() {
    let c1 = TestCondition()
    let c2 = TestCondition()
    let values = RecursiveLock([Bool]())
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

  @Test("||s Subscribed Values With 3 Conditions")
  func orsSubscribedValuesWith3Conditions() {
    let c1 = TestCondition()
    let c2 = TestCondition()
    let c3 = TestCondition()
    let values = RecursiveLock([Bool]())
    let subscription = (c1 || c2 || c3)
      .subscribe(in: QueryContext()) { value in
        values.withLock { $0.append(value) }
      }

    c1.send(true)
    c2.send(true)
    c3.send(true)
    c1.send(false)
    c2.send(false)
    c3.send(false)
    c1.send(true)
    c1.send(false)
    c2.send(true)
    c3.send(true)

    values.withLock {
      expectNoDifference($0, [true, true, true, true, true, false, true, false, true, true])
    }

    subscription.cancel()
  }

  @Test("&& Is True When Both Conditions Are True")
  func andTrueWhenBothTrue() {
    let c1: some FetchCondition = .always(true)
    let c2: some FetchCondition = .always(true)
    expectNoDifference((c1 && c2).isSatisfied(in: QueryContext()), true)
  }

  @Test("&& Is False When Right Condition Is False")
  func andFalseWhenRightFalse() {
    let c1: some FetchCondition = .always(true)
    let c2: some FetchCondition = .always(false)
    expectNoDifference((c1 && c2).isSatisfied(in: QueryContext()), false)
  }

  @Test("&& Is False When Left Condition Is False")
  func andFalseWhenLeftFalse() {
    let c1: some FetchCondition = .always(false)
    let c2: some FetchCondition = .always(true)
    expectNoDifference((c1 && c2).isSatisfied(in: QueryContext()), false)
  }

  @Test("&& Is False When Both Conditions Are False")
  func andFalseWhenBothFalse() {
    let c1: some FetchCondition = .always(false)
    let c2: some FetchCondition = .always(false)
    expectNoDifference((c1 && c2).isSatisfied(in: QueryContext()), false)
  }

  @Test("&&s Subscribed Values")
  func andsSubscribedValues() {
    let c1 = TestCondition()
    let c2 = TestCondition()
    let values = RecursiveLock([Bool]())
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

  @Test("&&s Subscribed Values With 3 Conditions")
  func andsSubscribedValuesWith3Conditions() {
    let c1 = TestCondition()
    let c2 = TestCondition()
    let c3 = TestCondition()
    let values = RecursiveLock([Bool]())
    let subscription = (c1 && c2 && c3)
      .subscribe(in: QueryContext()) { value in
        values.withLock { $0.append(value) }
      }

    c1.send(true)
    c2.send(true)
    c3.send(true)
    c1.send(false)
    c1.send(true)
    c2.send(false)
    c2.send(true)
    c3.send(false)

    values.withLock {
      expectNoDifference($0, [false, false, true, false, true, false, true, false])
    }

    subscription.cancel()
  }

  @Test("&& ||s Subscribed Values With 3 Conditions")
  func andOrsSubscribedValuesWith3Conditions() {
    let c1 = TestCondition()
    let c2 = TestCondition()
    let c3 = TestCondition()
    let values = RecursiveLock([Bool]())
    let subscription = ((c1 && c2) || c3)
      .subscribe(in: QueryContext()) { value in
        values.withLock { $0.append(value) }
      }

    c1.send(true)
    c2.send(true)
    c3.send(true)
    c1.send(false)
    c1.send(true)
    c2.send(false)
    c2.send(true)
    c3.send(false)
    c1.send(false)

    values.withLock {
      expectNoDifference($0, [false, true, true, true, true, true, true, true, false])
    }

    subscription.cancel()
  }

  @Test("&& (||)s Subscribed Values With 3 Conditions")
  func andParenOrsSubscribedValuesWith3Conditions() {
    let c1 = TestCondition()
    let c2 = TestCondition()
    let c3 = TestCondition()
    let values = RecursiveLock([Bool]())
    let subscription = (c1 && (c2 || c3))
      .subscribe(in: QueryContext()) { value in
        values.withLock { $0.append(value) }
      }

    c1.send(true)
    c2.send(true)
    c3.send(true)
    c1.send(false)
    c1.send(true)
    c2.send(false)
    c2.send(true)
    c3.send(false)
    c1.send(false)

    values.withLock {
      expectNoDifference($0, [false, true, true, false, true, true, true, true, false])
    }

    subscription.cancel()
  }
}
