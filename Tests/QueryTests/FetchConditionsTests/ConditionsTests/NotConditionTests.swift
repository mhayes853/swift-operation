import CustomDump
import Query
import Testing

@Suite("NotCondition tests")
struct NotConditionTests {
  @Test("Returns Opposite Of Base Condition When Satisfied")
  func returnsOppositeOfBaseConditionWhenSatisfied() {
    let condition: some FetchCondition = .always(true)
    let newCondition = !condition
    expectNoDifference(newCondition.isSatisfied(in: QueryContext()), false)
    expectNoDifference(!newCondition.isSatisfied(in: QueryContext()), true)
  }

  @Test("Emits Opposite Of Base Condition Observed Value")
  func emitsOppositeOfBaseConditionObservedValue() {
    let condition = TestCondition()
    let values = RecursiveLock([Bool]())
    let subscription = (!condition)
      .subscribe(in: QueryContext()) { value in
        values.withLock { $0.append(value) }
      }

    condition.send(true)
    condition.send(false)

    values.withLock { expectNoDifference($0, [false, true]) }
    subscription.cancel()
  }
}
