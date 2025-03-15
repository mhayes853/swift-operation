import CustomDump
import QueryCore
import Testing

@Suite("QueryController tests")
struct QueryControllerTests {
  @Test("Unsubscribes When Store Deallocated")
  func unsubscribeWhenStoreDeallocated() {
    let controller = TestController<TestQuery>()
    var store: QueryStoreFor<TestQuery>? = QueryStoreFor<TestQuery>
      .detached(query: TestQuery().controlled(by: controller), initialValue: nil)

    controller.controls.withLock { expectNoDifference($0 != nil, true) }
    store = nil
    controller.controls.withLock { expectNoDifference($0 == nil, true) }
    _ = store
  }

  @Test("Does Not Return Refetch Task When Automatic Fetching Disabled")
  func doesNotReturnRefetchTaskWhenAutomaticFetchingDisabled() {
    let controller = TestController<TestQuery>()
    let store = QueryStoreFor<TestQuery>
      .detached(
        query: TestQuery().controlled(by: controller)
          .enableAutomaticFetching(when: .always(false)),
        initialValue: nil
      )

    let task = controller.controls.withLock { $0?.yieldRefetchTask() }
    expectNoDifference(task == nil, true)
    _ = store
  }

  @Test("Refetches Data")
  func refetchesData() async throws {
    let controller = TestController<TestQuery>()
    let store = QueryStoreFor<TestQuery>
      .detached(
        query: TestQuery().controlled(by: controller)
          .enableAutomaticFetching(when: .always(true)),
        initialValue: nil
      )

    let task = controller.controls.withLock { $0?.yieldRefetchTask() }
    let value = try await task?.runIfNeeded()
    expectNoDifference(value, TestQuery.value)
    expectNoDifference(store.currentValue, TestQuery.value)
  }
}

private final class TestController<Query: QueryProtocol>: QueryController {
  typealias State = Query.State

  let controls = Lock<QueryControls<State>?>(nil)

  func control(with controls: QueryControls<State>) -> QuerySubscription {
    self.controls.withLock { $0 = controls }
    return QuerySubscription {
      self.controls.withLock { $0 = nil }
    }
  }
}
