import CustomDump
import Operation
import Testing

@Suite("NotRunSpecification tests")
struct NotRunSpecificationTests {
  @Test("Returns Opposite Of Base Condition When Satisfied")
  func returnsOppositeOfBaseConditionWhenSatisfied() {
    let condition: some OperationRunSpecification = .always(true)
    let newCondition = !condition
    expectNoDifference(newCondition.isSatisfied(in: OperationContext()), false)
    expectNoDifference(!newCondition.isSatisfied(in: OperationContext()), true)
  }

  @Test("Emits Opposite Of Base Condition Observed Value")
  func emitsOppositeOfBaseConditionObservedValue() {
    let condition = TestRunSpecification()
    let values = RecursiveLock([Bool]())
    let spec = !condition
    let subscription = spec.subscribe(in: OperationContext()) {
      values.withLock { $0.append(spec.isSatisfied(in: OperationContext())) }
    }

    condition.send(true)
    condition.send(false)

    values.withLock { expectNoDifference($0, [false, true]) }
    subscription.cancel()
  }
}
