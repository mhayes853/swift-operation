import CustomDump
import Operation
import Testing

@Suite("AlwaysRunSpecification tests")
struct AlwaysRunSpecificationTests {
  @Test("Emits Initial When Specified")
  func emitsInitial() {
    let c: some OperationRunSpecification = .always(true, shouldEmitInitialValue: true)
    let value = RecursiveLock<Bool?>(nil)
    let subscription = c.subscribe(in: OperationContext()) { v in
      value.withLock { $0 = v }
    }

    value.withLock { expectNoDifference($0, true) }

    subscription.cancel()
  }

  @Test("Does Not Emit Initial By Default")
  func doesNotEmitInitialByDefault() {
    let c: some OperationRunSpecification = .always(true)
    let value = RecursiveLock<Bool?>(nil)
    let subscription = c.subscribe(in: OperationContext()) { v in
      value.withLock { $0 = v }
    }

    value.withLock { expectNoDifference($0, nil) }

    subscription.cancel()
  }
}
