import CustomDump
import QueryCore
import Testing
import _TestQueries

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
    let query = TestQuery().enableAutomaticFetching(when: .always(true))
      .refetchOnChange(of: condition)
    let store = QueryStore.detached(query: query, initialValue: nil)

    condition.send(true)
    await Task.megaYield()

    expectNoDifference(store.currentValue, TestQuery.value)
  }

  @Test("Does Not Refetch When Condition Changes To False")
  func doesNotRefetchWhenConditionChangesToFalse() async {
    let condition = TestCondition()
    condition.send(true)
    let query = TestQuery().refetchOnChange(of: condition)
    let store = QueryStore.detached(query: query, initialValue: nil)

    condition.send(false)
    await Task.megaYield()

    expectNoDifference(store.currentValue, nil)
  }
}
