#if !os(WASI)
  import CustomDump
  import Foundation
  import QueryCore
  import Testing

  @Suite("NotificationFocusCondition tests", .serialized)
  struct NotificationFocusConditionTests {
    @Test("Uses Default Activity State", arguments: [true, false])
    func defaultActivityState(isActive: Bool) {
      let observer: some FetchCondition = .notificationFocus(
        didBecomeActive: _didBecomeActive,
        willResignActive: _willResignActive,
        isActive: { @Sendable in isActive }
      )
      expectNoDifference(observer.isSatisfied(in: QueryContext()), isActive)
    }

    @Test("Emits True When Becomes Active")
    func emitsTrueWhenBecomesActive() {
      let observer: some FetchCondition = .notificationFocus(
        didBecomeActive: _didBecomeActive,
        willResignActive: _willResignActive,
        isActive: { @Sendable in true }
      )
      let satisfactions = RecursiveLock([Bool]())
      let subscription = observer.subscribe(in: QueryContext()) { value in
        satisfactions.withLock { $0.append(value) }
      }
      NotificationCenter.default.post(name: _didBecomeActive, object: nil)
      satisfactions.withLock { expectNoDifference($0, [true]) }
      subscription.cancel()
    }

    @Test("Emits False When Resigns Active")
    func emitsFalseWhenResignsActive() {
      let observer: some FetchCondition = .notificationFocus(
        didBecomeActive: _didBecomeActive,
        willResignActive: _willResignActive,
        isActive: { @Sendable in true }
      )
      let satisfactions = RecursiveLock([Bool]())
      let subscription = observer.subscribe(in: QueryContext()) { value in
        satisfactions.withLock { $0.append(value) }
      }
      NotificationCenter.default.post(name: _willResignActive, object: nil)
      satisfactions.withLock { expectNoDifference($0, [false]) }
      subscription.cancel()
    }
  }

  private let _didBecomeActive = Notification.Name("FakeDidBecomeActiveNotification")
  private let _willResignActive = Notification.Name("FakeWillResignActiveNotification")
#endif
