#if !os(WASI)
  import CustomDump
  import Foundation
  @_spi(ApplicationActivityObserver) import Query
  import Testing

  @MainActor
  @Suite("ApplicationIsActiveCondition tests")
  struct ApplicationIsActiveConditionTests {
    private let center = NotificationCenter()

    @Test("Uses Default Activity State", arguments: [true, false])
    func defaultActivityState(isActive: Bool) {
      let observer = TestApplicationActivityObserver(isInitiallyActive: isActive)
      let condition: some FetchCondition = .applicationIsActive(
        observer: observer,
        center: self.center
      )
      expectNoDifference(condition.isSatisfied(in: QueryContext()), isActive)
    }

    @Test("Is Always False When Context Disables Focus Fetching", arguments: [true, false])
    func alwaysFalseWhenContextDisablesFocusFetching(isActive: Bool) {
      let observer = TestApplicationActivityObserver(isInitiallyActive: isActive)
      let condition: some FetchCondition = .applicationIsActive(
        observer: observer,
        center: self.center
      )
      var context = QueryContext()
      context.isApplicationActiveRefetchingEnabled = false
      expectNoDifference(condition.isSatisfied(in: context), false)
    }

    @Test("Emits False With Empty Subscription When Subscription Context Disables Focus Fetching")
    func emitsFalseWithEmptySubscripitionWhenFocusFetchingDisabled() {
      let observer = TestApplicationActivityObserver(isInitiallyActive: true)
      let condition: some FetchCondition = .applicationIsActive(
        observer: observer,
        center: self.center
      )
      let satisfactions = Lock([Bool]())
      var context = QueryContext()
      context.isApplicationActiveRefetchingEnabled = false
      let subscription = condition.subscribe(in: context) { value in
        satisfactions.withLock { $0.append(value) }
      }
      expectNoDifference(subscription, .empty)
      satisfactions.withLock { expectNoDifference($0, [false]) }
      subscription.cancel()
    }

    @Test("Emits True When Becomes Active")
    func emitsTrueWhenBecomesActive() {
      let observer = TestApplicationActivityObserver(isInitiallyActive: true)
      let condition: some FetchCondition = .applicationIsActive(
        observer: observer,
        center: self.center
      )
      let satisfactions = Lock([Bool]())
      let subscription = condition.subscribe(in: QueryContext()) { value in
        satisfactions.withLock { $0.append(value) }
      }
      self.center.post(name: .fakeDidBecomeActive, object: nil)
      satisfactions.withLock { expectNoDifference($0, [true]) }
      subscription.cancel()
    }

    @Test("Emits False When Resigns Active")
    func emitsFalseWhenResignsActive() {
      let observer = TestApplicationActivityObserver(isInitiallyActive: true)
      let condition: some FetchCondition = .applicationIsActive(
        observer: observer,
        center: self.center
      )
      let satisfactions = RecursiveLock([Bool]())
      let subscription = condition.subscribe(in: QueryContext()) { value in
        satisfactions.withLock { $0.append(value) }
      }
      self.center.post(name: .fakeWillResignActive, object: nil)
      satisfactions.withLock { expectNoDifference($0, [false]) }
      subscription.cancel()
    }
  }
#endif
