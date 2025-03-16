import CustomDump
import QueryCore
import Testing

@Suite("RefetchOnChangeQuery tests")
struct RefetchOnChangeQueryTests {
  @Test("Does Not Refetch Immediately")
  func doesNotRefetchImmediately() async {
    let condition = TestCondition()
    condition.send(true)
    let query = TestQuery().refetchOnChange(of: condition)
    let store = QueryStoreFor<TestQuery>.detached(query: query, initialValue: nil)

    await Task.megaYield()

    expectNoDifference(store.currentValue, nil)
  }

  @Test("Refetches When Condition Changes To True")
  func refetchesWhenConditionChangesToTrue() async {
    let condition = TestCondition()
    condition.send(false)
    let query = TestQuery().refetchOnChange(of: condition)
    let store = QueryStoreFor<TestQuery>.detached(query: query, initialValue: nil)

    condition.send(true)
    await Task.megaYield()

    expectNoDifference(store.currentValue, TestQuery.value)
  }

  @Test("Does Not Refetch When Condition Changes To False")
  func doesNotRefetchWhenConditionChangesToFalse() async {
    let condition = TestCondition()
    condition.send(true)
    let query = TestQuery().refetchOnChange(of: condition)
    let store = QueryStoreFor<TestQuery>.detached(query: query, initialValue: nil)

    condition.send(false)
    await Task.megaYield()

    expectNoDifference(store.currentValue, nil)
  }

  @Test("Only Creates 1 Condition Subscription For Multiple QueryStore Instances")
  func onlyCreatesOneConditionSubscriptionForMultipleQueryStoreInstances() async {
    let condition = TestCondition()
    condition.send(true)
    let query = TestQuery().refetchOnChange(of: condition)
    let store1 = QueryStoreFor<TestQuery>.detached(query: query, initialValue: nil)
    let store2 = QueryStoreFor<TestQuery>.detached(query: query, initialValue: nil)

    expectNoDifference(condition.subscriberCount, 1)
    _ = (store1, store2)
  }

  @Test("Only Removes Condition Subscription When All QueryStore Instances Are Deallocated")
  func onlyRemovesConditionSubscriptionWhenAllQueryStoreInstancesAreDeallocated() async {
    let condition = TestCondition()
    condition.send(true)
    let query = TestQuery().refetchOnChange(of: condition)
    var store1: QueryStoreFor<TestQuery>? = .detached(query: query, initialValue: nil)
    var store2: QueryStoreFor<TestQuery>? = .detached(query: query, initialValue: nil)

    store2 = nil
    expectNoDifference(condition.subscriberCount, 1)
    store1 = nil
    expectNoDifference(condition.subscriberCount, 0)
    _ = (store1, store2)
  }
}
