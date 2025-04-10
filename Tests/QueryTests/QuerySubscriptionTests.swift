import CustomDump
import Query
import Testing
import _TestQueries

@Suite("QuerySubscription tests")
struct QuerySubscriptionTests {
  @Test("Decrements Subscriber Count When Cancelled")
  func decrementsSubscriberCount() {
    let query = TestQuery().enableAutomaticFetching(onlyWhen: .always(false))
    let store = QueryClient().store(for: query)

    let subscription = store.subscribe(with: QueryEventHandler())
    expectNoDifference(store.subscriberCount, 1)
    subscription.cancel()
    expectNoDifference(store.subscriberCount, 0)
  }

  @Test("Cancels When Deallocated")
  func cancelsWhenDeallocated() {
    let query = TestQuery().enableAutomaticFetching(onlyWhen: .always(false))
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

  @Test("Combined Cancels All Subscriptions")
  func combinedCancelsAllSubscriptions() {
    var subs = [QuerySubscription]()
    let count = Lock(0)
    subs.append(QuerySubscription { count.withLock { $0 += 1 } })
    subs.append(QuerySubscription { count.withLock { $0 += 1 } })
    subs.append(QuerySubscription { count.withLock { $0 += 1 } })
    let subscription = QuerySubscription.combined(subs)
    subscription.cancel()

    count.withLock { expectNoDifference($0, 3) }
  }

  @Test(
    "Equality",
    arguments: [
      (QuerySubscription.empty, QuerySubscription.empty, true),
      (QuerySubscription {}, QuerySubscription.empty, false),
      (QuerySubscription {}, QuerySubscription {}, false),
      (QuerySubscription.staticSub, QuerySubscription.staticSub, true),
      (QuerySubscription.staticSub, QuerySubscription {}, false),
      (QuerySubscription.combined([]), QuerySubscription.combined([]), true),
      (QuerySubscription.combined([]), QuerySubscription.combined([.empty]), false),
      (QuerySubscription.combined([.empty]), QuerySubscription.combined([.empty]), true),
      (QuerySubscription.combined([.empty]), QuerySubscription.combined([.staticSub]), false),
      (QuerySubscription.combined([.staticSub]), QuerySubscription.combined([.staticSub]), true),
      (
        QuerySubscription.combined([.staticSub, .empty]),
        QuerySubscription.combined([.staticSub]),
        false
      )
    ]
  )
  func equality(s1: QuerySubscription, s2: QuerySubscription, isEqual: Bool) {
    expectNoDifference(s1 == s2, isEqual)
    expectNoDifference(s1.hashValue == s2.hashValue, isEqual)
  }
}

extension QuerySubscription {
  fileprivate static let staticSub = QuerySubscription {}
}
