import Foundation
import Operation
import Testing

@Suite("OperationSubscription Deadlock tests")
struct OperationSubscriptionDeadlockTests {
  #if swift(>=6.2) && (os(Linux) || os(macOS) || os(Windows))
    @Test
    func `Subscriber Can Read The Subscriber Count From A Callback`() async {
      await withKnownIssue("OperationSubscriptions invokes callbacks while holding its lock.") {
        await #expect(processExitsWith: .success) {
          DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            exit(42)
          }
          let observer = MockNetworkObserver(initialStatus: .connected)
          let subscription = observer.subscribe { status in
            guard status == .disconnected else { return }
            _ = observer.subscriberCount
          }
          observer.send(status: .disconnected)
          _ = subscription
        }
      }
    }

    @Test
    func `Subscription Can Cancel Itself From Its Cancellation Handler`() async {
      await withKnownIssue(
        "OperationSubscription invokes its cancellation handler while holding its lock."
      ) {
        await #expect(processExitsWith: .success) {
          DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            exit(42)
          }
          let holder = RecursiveLock<OperationSubscription?>(nil)
          let subscription = OperationSubscription {
            holder.withLock { $0?.cancel() }
          }
          holder.withLock { $0 = subscription }
          subscription.cancel()
        }
      }
    }
  #endif
}
