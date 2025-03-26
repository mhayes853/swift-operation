import CustomDump
import QueryCore
import Testing

@Suite("AlwaysCondition tests")
struct AlwaysConditionTests {
  @Test("Emits Initial When Specified")
  func emitsInitial() {
    let c: some FetchCondition = .always(true, shouldEmitInitialValue: true)
    let value = RecursiveLock<Bool?>(nil)
    let subscription = c.subscribe(in: QueryContext()) { v in
      value.withLock { $0 = v }
    }

    value.withLock { expectNoDifference($0, true) }

    subscription.cancel()
  }

  @Test("Does Not Emit Initial By Default")
  func doesNotEmitInitialByDefault() {
    let c: some FetchCondition = .always(true)
    let value = RecursiveLock<Bool?>(nil)
    let subscription = c.subscribe(in: QueryContext()) { v in
      value.withLock { $0 = v }
    }

    value.withLock { expectNoDifference($0, nil) }

    subscription.cancel()
  }
}
