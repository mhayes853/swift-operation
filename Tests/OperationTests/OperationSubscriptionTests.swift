import CustomDump
import Foundation
import Operation
import OperationTestHelpers
import Testing

@Suite("OperationSubscription tests")
struct OperationSubscriptionTests {
  @Test("Decrements Subscriber Count When Cancelled")
  func decrementsSubscriberCount() {
    let query = TestQuery().disableAutomaticRunning()
    let store = OperationClient().store(for: query)

    let subscription = store.subscribe(with: QueryEventHandler())
    expectNoDifference(store.subscriberCount, 1)
    subscription.cancel()
    expectNoDifference(store.subscriberCount, 0)
  }

  @Test("Cancels When Deallocated")
  func cancelsWhenDeallocated() {
    let query = TestQuery().disableAutomaticRunning()
    let store = OperationClient().store(for: query)
    do {
      let subscription = store.subscribe(with: QueryEventHandler())
      expectNoDifference(store.subscriberCount, 1)
      _ = subscription
    }
    expectNoDifference(store.subscriberCount, 0)
  }

  @Test("Stores In Set")
  func storesInSet() {
    var subs = Set<OperationSubscription>()
    let subscription = OperationSubscription.empty
    subscription.store(in: &subs)

    expectNoDifference(subs.contains(subscription), true)
    subs.remove(subscription)
    expectNoDifference(subs.contains(subscription), false)
  }

  @Test("Stores In Collection")
  func storesInCollection() {
    var subs = [OperationSubscription]()
    let subscription = OperationSubscription.empty
    subscription.store(in: &subs)

    expectNoDifference(subs.contains(subscription), true)
    subs.removeAll { $0 == subscription }
    expectNoDifference(subs.contains(subscription), false)
  }

  @Test("Combined Cancels All Subscriptions")
  func combinedCancelsAllSubscriptions() {
    var subs = [OperationSubscription]()
    let count = Lock(0)
    subs.append(OperationSubscription { count.withLock { $0 += 1 } })
    subs.append(OperationSubscription { count.withLock { $0 += 1 } })
    subs.append(OperationSubscription { count.withLock { $0 += 1 } })
    let subscription = OperationSubscription.combined(subs)
    subscription.cancel()

    count.withLock { expectNoDifference($0, 3) }
  }

  #if swift(>=6.2) && (os(Linux) || os(macOS) || os(Windows))
    @Test("Subscriber Can Read The Subscriber Count From A Callback")
    func subscriberCanReadSubscriberCountFromCallback() async {
      await #expect(processExitsWith: .success) {
        let watchdog = Task {
          try await Task.sleep(nanoseconds: 1_000_000_000)
          exit(42)
        }
        defer { watchdog.cancel() }
        let observer = MockNetworkObserver(initialStatus: .connected)
        let subscription = observer.subscribe { status in
          guard status == .disconnected else { return }
          _ = observer.subscriberCount
        }
        observer.send(status: .disconnected)
        _ = subscription
      }
    }

    @Test("Subscriber Can Cancel Itself From A Callback")
    func subscriberCanCancelItselfFromCallback() async {
      await #expect(processExitsWith: .success) {
        let watchdog = Task {
          try await Task.sleep(nanoseconds: 1_000_000_000)
          exit(42)
        }
        defer { watchdog.cancel() }
        let callbackCount = RecursiveLock(0)
        let holder = RecursiveLock<OperationSubscription?>(nil)
        let observer = MockNetworkObserver(initialStatus: .connected)
        let subscription = observer.subscribe { status in
          guard status == .disconnected else { return }
          callbackCount.withLock { $0 += 1 }
          holder.withLock { $0?.cancel() }
        }
        holder.withLock { $0 = subscription }
        observer.send(status: .disconnected)
        observer.send(status: .disconnected)
        callbackCount.withLock { expectNoDifference($0, 1) }
        expectNoDifference(observer.subscriberCount, 0)
      }
    }

    @Test("Subscription Can Cancel Itself From Its Cancellation Handler")
    func subscriptionCanCancelItselfFromCancellationHandler() async {
      await #expect(processExitsWith: .success) {
        let watchdog = Task {
          try await Task.sleep(nanoseconds: 1_000_000_000)
          exit(42)
        }
        defer { watchdog.cancel() }
        let cancellationCount = RecursiveLock(0)
        let holder = RecursiveLock<OperationSubscription?>(nil)
        let subscription = OperationSubscription {
          cancellationCount.withLock { $0 += 1 }
          holder.withLock { $0?.cancel() }
        }
        holder.withLock { $0 = subscription }
        subscription.cancel()
        cancellationCount.withLock { expectNoDifference($0, 1) }
      }
    }
  #endif

  @Test(
    "Equality",
    arguments: [
      (OperationSubscription.empty, OperationSubscription.empty, true),
      (OperationSubscription {}, OperationSubscription.empty, false),
      (OperationSubscription {}, OperationSubscription {}, false),
      (OperationSubscription.staticSub, OperationSubscription.staticSub, true),
      (OperationSubscription.staticSub, OperationSubscription {}, false),
      (OperationSubscription.combined([]), OperationSubscription.combined([]), true),
      (OperationSubscription.combined([]), OperationSubscription.combined([.empty]), false),
      (OperationSubscription.combined([.empty]), OperationSubscription.combined([.empty]), true),
      (
        OperationSubscription.combined([.empty]), OperationSubscription.combined([.staticSub]),
        false
      ),
      (
        OperationSubscription.combined([.staticSub]), OperationSubscription.combined([.staticSub]),
        true
      ),
      (
        OperationSubscription.combined([.staticSub, .empty]),
        OperationSubscription.combined([.staticSub]),
        false
      )
    ]
  )
  func equality(s1: OperationSubscription, s2: OperationSubscription, isEqual: Bool) {
    expectNoDifference(s1 == s2, isEqual)
    expectNoDifference(s1.hashValue == s2.hashValue, isEqual)
  }
}

extension OperationSubscription {
  fileprivate static let staticSub = OperationSubscription {}
}
