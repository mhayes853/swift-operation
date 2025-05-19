#if !os(WASI)
  import CustomDump
  import Foundation
  import Query
  import Testing

  @Suite("ApplicationIsActiveCondition tests")
  struct ApplicationIsActiveConditionTests {
    private let center = NotificationCenter()

    @Test("Uses Default Activity State", arguments: [true, false])
    func defaultActivityState(isActive: Bool) {
      let observer: some FetchCondition = .applicationIsActive(
        didBecomeActive: .fakeDidBecomeActive,
        willResignActive: .fakeWillResignActive,
        center: self.center,
        isActive: { @Sendable in isActive }
      )
      expectNoDifference(observer.isSatisfied(in: QueryContext()), isActive)
    }

    @Test("Is Always False When Context Disables Focus Fetching", arguments: [true, false])
    func alwaysFalseWhenContextDisablesFocusFetching(isActive: Bool) {
      let observer: some FetchCondition = .applicationIsActive(
        didBecomeActive: .fakeDidBecomeActive,
        willResignActive: .fakeWillResignActive,
        center: self.center,
        isActive: { @Sendable in isActive }
      )
      var context = QueryContext()
      context.isFocusRefetchingEnabled = false
      expectNoDifference(observer.isSatisfied(in: context), false)
    }

    @Test("Emits False With Empty Subscription When Subscription Context Disables Focus Fetching")
    func emitsFalseWithEmptySubscripitionWhenFocusFetchingDisabled() {
      let observer: some FetchCondition = .applicationIsActive(
        didBecomeActive: .fakeDidBecomeActive,
        willResignActive: .fakeWillResignActive,
        center: self.center,
        isActive: { @Sendable in true }
      )
      let satisfactions = Lock([Bool]())
      var context = QueryContext()
      context.isFocusRefetchingEnabled = false
      let subscription = observer.subscribe(in: context) { value in
        satisfactions.withLock { $0.append(value) }
      }
      expectNoDifference(subscription, .empty)
      satisfactions.withLock { expectNoDifference($0, [false]) }
      subscription.cancel()
    }

    @Test("Emits True When Becomes Active")
    func emitsTrueWhenBecomesActive() {
      let observer: some FetchCondition = .applicationIsActive(
        didBecomeActive: .fakeDidBecomeActive,
        willResignActive: .fakeWillResignActive,
        center: self.center,
        isActive: { @Sendable in true }
      )
      let satisfactions = RecursiveLock([Bool]())
      let subscription = observer.subscribe(in: QueryContext()) { value in
        satisfactions.withLock { $0.append(value) }
      }
      self.center.post(name: .fakeDidBecomeActive, object: nil)
      satisfactions.withLock { expectNoDifference($0, [true]) }
      subscription.cancel()
    }

    @Test("Emits False When Resigns Active")
    func emitsFalseWhenResignsActive() {
      let observer: some FetchCondition = .applicationIsActive(
        didBecomeActive: .fakeDidBecomeActive,
        willResignActive: .fakeWillResignActive,
        center: self.center,
        isActive: { @Sendable in true }
      )
      let satisfactions = RecursiveLock([Bool]())
      let subscription = observer.subscribe(in: QueryContext()) { value in
        satisfactions.withLock { $0.append(value) }
      }
      self.center.post(name: .fakeWillResignActive, object: nil)
      satisfactions.withLock { expectNoDifference($0, [false]) }
      subscription.cancel()
    }
  }
#endif
