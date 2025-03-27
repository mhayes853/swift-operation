import CustomDump
@_spi(StaleWhenRevalidateCondition) import QueryCore
import Testing

@Suite("StaleWhenRevalidateQuery tests")
struct StaleWhenRevalidateQueryTests {
  @Suite("StaleWhenRevalidateCondition tests")
  struct StaleWhenRevalidateConditionTests {
    @Test("True When Empty")
    func trueWhenEmpty() {
      let condition = StaleWhenRevalidateCondition()
      expectNoDifference(
        condition.evaluate(state: QueryState<Int?, Int>(initialValue: nil), in: QueryContext()),
        true
      )
    }

    @Test("True When Predicate Returns True")
    func trueWhenPredicateReturnsTrue() {
      var condition = StaleWhenRevalidateCondition()
      condition.add { state, _ in state.error == nil }
      expectNoDifference(
        condition.evaluate(state: QueryState<Int?, Int>(initialValue: nil), in: QueryContext()),
        true
      )
    }

    @Test("False When Predicate Returns False")
    func falseWhenPredicateReturnsFalse() {
      var condition = StaleWhenRevalidateCondition()
      condition.add { state, _ in state.valueUpdateCount > 0 }
      expectNoDifference(
        condition.evaluate(state: QueryState<Int?, Int>(initialValue: nil), in: QueryContext()),
        false
      )
    }

    @Test("False When All Predicates Return False")
    func falseWhenAllPredicatesReturnFalse() {
      var condition = StaleWhenRevalidateCondition()
      condition.add { state, _ in state.valueUpdateCount > 0 }
      condition.add { state, _ in state.isLoading }
      expectNoDifference(
        condition.evaluate(state: QueryState<Int?, Int>(initialValue: nil), in: QueryContext()),
        false
      )
    }

    @Test("Ors All Predicates")
    func orsAllPredicates() {
      var condition = StaleWhenRevalidateCondition()
      let context = QueryContext()
      condition.add { _, c in c.testCount > 0 }
      condition.add { _, c in c.testCount == 0 }
      let state = QueryState<Int?, Int>(initialValue: nil)
      expectNoDifference(condition.evaluate(state: state, in: context), true)
      expectNoDifference(condition.evaluate(state: state, in: context), true)
    }
  }

}

extension QueryContext {
  fileprivate var testCount: Int {
    get { self[TestCountKey.self] }
    set { self[TestCountKey.self] = newValue }
  }

  private enum TestCountKey: Key {
    static var defaultValue: Int { 0 }
  }
}
