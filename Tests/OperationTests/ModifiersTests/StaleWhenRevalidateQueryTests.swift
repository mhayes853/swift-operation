import CustomDump
import Foundation
@_spi(StaleWhenRevalidateCondition) import Operation
import OperationTestHelpers
import Testing

@Suite("StaleWhenRevalidateQuery tests")
struct StaleWhenRevalidateQueryTests {
  @Suite("StaleWhenRevalidateCondition tests")
  struct StaleWhenRevalidateConditionTests {
    @Test("True When Empty")
    func trueWhenEmpty() {
      let condition = StaleWhenRevalidateCondition()
      expectNoDifference(
        condition.evaluate(
          state: QueryState<Int, any Error>(initialValue: nil),
          in: OperationContext()
        ),
        true
      )
    }

    @Test("True When Predicate Returns True")
    func trueWhenPredicateReturnsTrue() {
      var condition = StaleWhenRevalidateCondition()
      condition.add { state, _ in state.error == nil }
      expectNoDifference(
        condition.evaluate(
          state: QueryState<Int, any Error>(initialValue: nil),
          in: OperationContext()
        ),
        true
      )
    }

    @Test("False When Predicate Returns False")
    func falseWhenPredicateReturnsFalse() {
      var condition = StaleWhenRevalidateCondition()
      condition.add { state, _ in state.valueUpdateCount > 0 }
      expectNoDifference(
        condition.evaluate(
          state: QueryState<Int, any Error>(initialValue: nil),
          in: OperationContext()
        ),
        false
      )
    }

    @Test("False When All Predicates Return False")
    func falseWhenAllPredicatesReturnFalse() {
      var condition = StaleWhenRevalidateCondition()
      condition.add { state, _ in state.valueUpdateCount > 0 }
      condition.add { state, _ in state.isLoading }
      expectNoDifference(
        condition.evaluate(
          state: QueryState<Int, any Error>(initialValue: nil),
          in: OperationContext()
        ),
        false
      )
    }

    @Test("Ors All Predicates")
    func orsAllPredicates() {
      var condition = StaleWhenRevalidateCondition()
      let context = OperationContext()
      condition.add { _, c in c.testCount > 0 }
      condition.add { _, c in c.testCount == 0 }
      condition.add { _, c in c.testCount < 0 }
      let state = QueryState<Int, any Error>(initialValue: nil)
      expectNoDifference(condition.evaluate(state: state, in: context), true)
    }
  }

  @Test("Store Is Always Stale By Default")
  func storeIsAlwaysStaleByDefault() {
    let store = OperationStore.detached(query: TestQuery(), initialValue: nil)
    expectNoDifference(store.isStale, true)
  }

  @Test("Stale After Seconds")
  func staleAfterSeconds() async throws {
    let clock = TestOperationClock(date: Date())
    let query = TestQuery().stale(after: 1)
    let store = OperationStore.detached(query: query, initialValue: nil)
    store.context.operationClock = clock

    expectNoDifference(store.isStale, true)

    try await store.fetch()
    expectNoDifference(store.isStale, false)

    clock.date += 2
    expectNoDifference(store.isStale, true)
  }

  @Test("Stale When No Value")
  func staleWhenHasValue() async throws {
    let query = TestQuery().staleWhenNoValue()
    let store = OperationStore.detached(query: query, initialValue: nil)

    expectNoDifference(store.isStale, true)
    try await store.fetch()
    expectNoDifference(store.isStale, false)
  }

  @Test("Stale When Condition")
  func staleWhenCondition() async throws {
    let query = TestQuery().staleWhen { state, _ in state.valueUpdateCount == 0 }
    let store = OperationStore.detached(query: query, initialValue: nil)

    expectNoDifference(store.isStale, true)

    try await store.fetch()
    expectNoDifference(store.isStale, false)
  }

  @Test("Stale When Fetch Condition")
  func staleWhenFetchCondition() {
    let condition = TestCondition()
    condition.send(true)
    let query = TestQuery().staleWhen(condition: condition)
    let store = OperationStore.detached(query: query, initialValue: nil)

    expectNoDifference(store.isStale, true)

    condition.send(false)
    expectNoDifference(store.isStale, false)
  }

  @Test("Ors Stale Modifiers Together")
  func orsStaleModifiersTogether() async throws {
    let clock = TestOperationClock(date: Date())
    let query = TestQuery().stale(after: 1000).staleWhen { state, _ in state.valueUpdateCount == 0 }
    let store = OperationStore.detached(query: query, initialValue: nil)
    store.context.operationClock = clock

    expectNoDifference(store.isStale, true)

    try await store.fetch()
    expectNoDifference(store.isStale, false)

    clock.date += 1001
    expectNoDifference(store.isStale, true)
  }

  @Test("Condition False When Incorrect State Type Evaluated")
  func conditionFalseWhenIncorrectStateTypeEvaluated() async throws {
    let query = TestQuery().staleWhen { state, _ in state.valueUpdateCount == 0 }
    let store = OperationStore.detached(query: query, initialValue: nil)
    let state = MutationState<Int, String, any Error>()
    expectNoDifference(
      store.context.staleWhenRevalidateCondition.evaluate(state: state, in: OperationContext()),
      false
    )
  }

  @Test("Fetches On Subscription When Stale")
  func fetchesOnSubscriptionWhenStale() async throws {
    let query = TestQuery().enableAutomaticFetching(onlyWhen: .always(true))
      .staleWhen(condition: .always(true))
    let store = OperationStore.detached(query: query, initialValue: nil)

    let subscription = store.subscribe(with: QueryEventHandler())
    _ = try await store.activeTasks.first?.runIfNeeded()
    expectNoDifference(store.valueUpdateCount, 1)
    subscription.cancel()
  }

  @Test("Does Not Fetch On Subscription When Not Stale")
  func doesNotFetchOnSubscriptionWhenNotStale() async throws {
    let query = TestQuery().staleWhen(condition: .always(false))
    let store = OperationStore.detached(query: query, initialValue: nil)

    let subscription = store.subscribe(with: QueryEventHandler())
    expectNoDifference(store.activeTasks, [])
    subscription.cancel()
  }
}

extension OperationContext {
  fileprivate var testCount: Int {
    get { self[TestCountKey.self] }
    set { self[TestCountKey.self] = newValue }
  }

  private enum TestCountKey: Key {
    static var defaultValue: Int { 0 }
  }
}
