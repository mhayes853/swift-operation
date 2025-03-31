import CustomDump
import Query
import Testing
import _TestQueries

@Suite("QuerySubscription tests")
struct QuerySubscriptionTests {
  @Test("Decrements Subscriber Count When Cancelled")
  func decrementsSubscriberCount() {
    let query = TestQuery().enableAutomaticFetching(when: .always(false))
    let store = QueryClient().store(for: query)

    let subscription = store.subscribe(with: QueryEventHandler())
    expectNoDifference(store.subscriberCount, 1)
    subscription.cancel()
    expectNoDifference(store.subscriberCount, 0)
  }

  @Test("Cancels When Deallocated")
  func cancelsWhenDeallocated() {
    let query = TestQuery().enableAutomaticFetching(when: .always(false))
    let store = QueryClient().store(for: query)
    do {
      let subscription = store.subscribe(with: QueryEventHandler())
      expectNoDifference(store.subscriberCount, 1)
      _ = subscription
    }
    expectNoDifference(store.subscriberCount, 0)
  }

  @Test("Stores In Set")
  func storesInSet() {
    var subs = Set<QuerySubscription>()
    let subscription = QuerySubscription.empty
    subscription.store(in: &subs)

    expectNoDifference(subs.contains(subscription), true)
    subs.remove(subscription)
    expectNoDifference(subs.contains(subscription), false)
  }

  @Test("Stores In Collection")
  func storesInCollection() {
    var subs = [QuerySubscription]()
    let subscription = QuerySubscription.empty
    subscription.store(in: &subs)

    expectNoDifference(subs.contains(subscription), true)
    subs.removeAll { $0 == subscription }
    expectNoDifference(subs.contains(subscription), false)
  }
}
