import CustomDump
import QueryCore
import Testing

@Suite("QueryStoreSubscription tests")
struct QueryStoreSubscriptionTests {
  @Test("Decrements Subscriber Count When Cancelled")
  func decrementsSubscriberCount() {
    let query = TestQuery().startFetching(when: .fetchManuallyCalled)
    let store = QueryClient().store(for: query)

    let subscription = store.subscribe { _ in }
    expectNoDifference(store.subscriberCount, 1)
    subscription.cancel()
    expectNoDifference(store.subscriberCount, 0)
  }

  @Test("Cancels When Deallocated")
  func cancelsWhenDeallocated() {
    let query = TestQuery().startFetching(when: .fetchManuallyCalled)
    let store = QueryClient().store(for: query)
    do {
      let subscription = store.subscribe { _ in }
      expectNoDifference(store.subscriberCount, 1)
      _ = subscription
    }
    expectNoDifference(store.subscriberCount, 0)
  }
}
