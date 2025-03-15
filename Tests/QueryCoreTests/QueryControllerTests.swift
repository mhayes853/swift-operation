import CustomDump
import Foundation
import QueryCore
import Testing

@Suite("QueryController tests")
struct QueryControllerTests {
  @Test("Unsubscribes When Store Deallocated")
  func unsubscribeWhenStoreDeallocated() {
    let controller = TestQueryController<TestQuery>()
    var store: QueryStoreFor<TestQuery>? = QueryStoreFor<TestQuery>
      .detached(query: TestQuery().controlled(by: controller), initialValue: nil)

    controller.controls.withLock { expectNoDifference($0 != nil, true) }
    store = nil
    controller.controls.withLock { expectNoDifference($0 == nil, true) }
    _ = store
  }

  @Test("Does Not Return Refetch Task When Automatic Fetching Disabled")
  func doesNotReturnRefetchTaskWhenAutomaticFetchingDisabled() {
    let controller = TestQueryController<TestQuery>()
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
    let controller = TestQueryController<TestQuery>()
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

  @Test("Yields New State Value To Query")
  func yieldsNewStateValueToQuery() async throws {
    let controller = TestQueryController<TestQuery>()
    let store = QueryStoreFor<TestQuery>
      .detached(
        query: TestQuery().controlled(by: controller)
          .enableAutomaticFetching(when: .always(true)),
        initialValue: nil
      )

    let date = Lock(Date())
    store.context.queryClock = .custom { date.withLock { $0 } }

    controller.controls.withLock { $0?.yield(10) }
    expectNoDifference(store.currentValue, 10)
    expectNoDifference(store.valueUpdateCount, 1)
    expectNoDifference(store.valueLastUpdatedAt, date.withLock { $0 })

    date.withLock { $0 = .distantFuture }
    controller.controls.withLock { $0?.yield(20) }
    expectNoDifference(store.currentValue, 20)
    expectNoDifference(store.valueUpdateCount, 2)
    expectNoDifference(store.valueLastUpdatedAt, .distantFuture)
  }

  @Test("Yields New Error Value To Query")
  func yieldsNewErrorValueToQuery() async throws {
    let controller = TestQueryController<TestQuery>()
    let store = QueryStoreFor<TestQuery>
      .detached(
        query: TestQuery().controlled(by: controller)
          .enableAutomaticFetching(when: .always(true)),
        initialValue: nil
      )

    let date = Lock(Date())
    store.context.queryClock = .custom { date.withLock { $0 } }

    controller.controls.withLock { $0?.yield(throwing: SomeError.a) }
    expectNoDifference(store.error as? SomeError, .a)
    expectNoDifference(store.errorUpdateCount, 1)
    expectNoDifference(store.errorLastUpdatedAt, date.withLock { $0 })

    date.withLock { $0 = .distantFuture }
    controller.controls.withLock { $0?.yield(throwing: SomeError.b) }
    expectNoDifference(store.error as? SomeError, .b)
    expectNoDifference(store.errorUpdateCount, 2)
    expectNoDifference(store.errorLastUpdatedAt, .distantFuture)
  }
}

private enum SomeError: Equatable, Error {
  case a, b
}
