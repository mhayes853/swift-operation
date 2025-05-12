import CustomDump
import Query
import QueryTestHelpers
import Testing

@Suite("RefetchOnChangeQuery tests")
struct RefetchOnChangeQueryTests {
  @Test("Does Not Refetch Immediately")
  func doesNotRefetchImmediately() async {
    let condition = TestCondition()
    condition.send(true)
    let query = TestQuery().refetchOnChange(of: condition)
    let store = QueryStore.detached(query: query, initialValue: nil)

    await Task.megaYield()

    expectNoDifference(store.currentValue, nil)
  }

  @Test("Refetches When Condition Changes To True")
  func refetchesWhenConditionChangesToTrue() async {
    let condition = TestCondition()
    condition.send(false)

    let automaticCondition = TestCondition()
    automaticCondition.send(false)
    let store = QueryStore.detached(
      query: TestQuery().enableAutomaticFetching(onlyWhen: automaticCondition)
        .refetchOnChange(of: condition),
      initialValue: nil
    )
    let subscription = store.subscribe(with: QueryEventHandler())
    automaticCondition.send(true)

    condition.send(true)
    await Task.megaYield()

    expectNoDifference(store.currentValue, TestQuery.value)

    subscription.cancel()
  }

  @Test("Cancels In Progress Refetch When Condition Switches To False")
  func cancelsInProgressRefetchWhenRefetched() async {
    let condition = TestCondition()
    condition.send(false)

    let count = Lock(0)
    let automaticCondition = TestCondition()
    automaticCondition.send(false)
    let store = QueryStore.detached(
      query: CountingQuery {
        let c = count.withLock { count in
          count += 1
          return count
        }
        if c == 1 {
          try await Task.never()
        }
      }
      .enableAutomaticFetching(onlyWhen: automaticCondition)
      .refetchOnChange(of: condition),
      initialValue: nil
    )
    let subscription = store.subscribe(with: QueryEventHandler())
    automaticCondition.send(true)

    condition.send(true)
    await Task.megaYield()

    expectNoDifference(store.status.isCancelled, false)

    condition.send(false)
    await Task.megaYield()

    expectNoDifference(store.status.isCancelled, true)

    subscription.cancel()
  }

  @Test("Does Not Refetch When Condition Changes To False")
  func doesNotRefetchWhenConditionChangesToFalse() async {
    let condition = TestCondition()
    condition.send(true)

    let automaticCondition = TestCondition()
    automaticCondition.send(false)
    let store = QueryStore.detached(
      query: TestQuery().enableAutomaticFetching(onlyWhen: automaticCondition)
        .refetchOnChange(of: condition),
      initialValue: nil
    )
    let subscription = store.subscribe(with: QueryEventHandler())
    automaticCondition.send(true)

    condition.send(false)
    await Task.megaYield()

    expectNoDifference(store.currentValue, nil)
    subscription.cancel()
  }

  @Test("Does Not Refetch When No Subscribers On QueryStore")
  func doesNotRefetchWhenNoSubscribersOnQueryStore() async {
    let condition = TestCondition()
    condition.send(false)

    let query = CountingQuery {}
    let store = QueryStore.detached(
      query: query.enableAutomaticFetching(onlyWhen: .always(true)).refetchOnChange(of: condition),
      initialValue: nil
    )

    condition.send(true)
    await Task.megaYield()

    let count = await query.fetchCount
    expectNoDifference(count, 0)
    expectNoDifference(store.currentValue, nil)
  }

  @Test("Does Not Refetch When Query Is Not Stale")
  func doesNotRefetchWhenQueryIsNotStale() async {
    let condition = TestCondition()
    condition.send(false)

    let automaticCondition = TestCondition()
    automaticCondition.send(false)
    let store = QueryStore.detached(
      query: TestQuery().enableAutomaticFetching(onlyWhen: automaticCondition)
        .refetchOnChange(of: condition)
        .staleWhen { _, _ in false },
      initialValue: nil
    )
    let subscription = store.subscribe(with: QueryEventHandler())
    automaticCondition.send(true)

    condition.send(true)
    await Task.megaYield()

    expectNoDifference(store.currentValue, nil)
    subscription.cancel()
  }
}
