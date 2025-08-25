import CustomDump
import Foundation
@_spi(Warnings) import Operation
@_spi(Warnings) import OperationTestHelpers
import Testing

@Suite("OperationController tests")
struct OperationControllerTests {
  @Test("Unsubscribes When Store Deallocated")
  func unsubscribeWhenStoreDeallocated() {
    let controller = TestOperationController<TestQuery>()
    var store: OperationStore<TestQuery.State>? = .detached(
      query: TestQuery().controlled(by: controller),
      initialValue: nil
    )

    controller.controls.withLock { expectNoDifference($0 != nil, true) }
    store = nil
    controller.controls.withLock { expectNoDifference($0 == nil, true) }
    _ = store
  }

  @Test("Does Not Return Refetch Task When Automatic Fetching Disabled")
  func doesNotReturnRefetchTaskWhenAutomaticFetchingDisabled() {
    let controller = TestOperationController<TestQuery>()
    let store = OperationStore.detached(
      query: TestQuery().controlled(by: controller)
        .disableAutomaticFetching(),
      initialValue: nil
    )

    let task = controller.controls.withLock { $0?.yieldRefetchTask() }
    expectNoDifference(task == nil, true)
    _ = store
  }

  @Test("Refetches Data")
  func refetchesData() async throws {
    let controller = TestOperationController<TestQuery>()
    let store = OperationStore.detached(
      query: TestQuery().controlled(by: controller)
        .enableAutomaticFetching(onlyWhen: .always(true)),
      initialValue: nil
    )

    let task = controller.controls.withLock { $0?.yieldRefetchTask() }
    let value = try await task?.runIfNeeded()
    expectNoDifference(value, TestQuery.value)
    expectNoDifference(store.currentValue, TestQuery.value)
  }

  @Test("Yields New State Value To Query")
  func yieldsNewStateValueToQuery() async throws {
    let controller = TestOperationController<TestQuery>()
    let store = OperationStore.detached(
      query: TestQuery().controlled(by: controller)
        .enableAutomaticFetching(onlyWhen: .always(true)),
      initialValue: nil
    )

    let date = RecursiveLock(Date())
    store.context.operationClock = .custom { date.withLock { $0 } }

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
    let controller = TestOperationController<TestQuery>()
    let store = OperationStore.detached(
      query: TestQuery().controlled(by: controller)
        .enableAutomaticFetching(onlyWhen: .always(true)),
      initialValue: nil
    )

    let date = RecursiveLock(Date())
    store.context.operationClock = .custom { date.withLock { $0 } }

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

  @Test("Yields New State Value To Query, Emits State Changed Event")
  func yieldsNewStateValueToQueryEmitsStateChangedEvent() async throws {
    let controller = TestOperationController<TestQuery>()
    let store = OperationStore.detached(
      query: TestQuery().controlled(by: controller)
        .disableAutomaticFetching(),
      initialValue: nil
    )
    let collector = OperationStoreEventsCollector<TestQuery.State>()
    let subscription = store.subscribe(with: collector.eventHandler())
    controller.controls.withLock { $0?.yield(10) }
    collector.expectEventsMatch([.stateChanged, .stateChanged])
    subscription.cancel()
  }

  @Test("Yields Reset To Query")
  func yieldsResetToQuery() async throws {
    let controller = TestOperationController<TestQuery>()
    let store = OperationStore.detached(
      query: TestQuery().controlled(by: controller),
      initialValue: nil
    )
    try await store.fetch()

    expectNoDifference(store.currentValue, TestQuery.value)
    controller.controls.withLock { $0?.yieldResetState() }
    expectNoDifference(store.currentValue, nil)
  }

  @Test("Yield Result Based Off Of Current State")
  func yieldResultToQueryBasedOffCurrentState() async throws {
    let controller = TestOperationController<TestQuery>()
    let store = OperationStore.detached(
      query: TestQuery().controlled(by: controller),
      initialValue: nil
    )
    try await store.fetch()

    expectNoDifference(store.currentValue, TestQuery.value)
    controller.controls.withLock { controls in
      controls!.withExclusiveAccess { $0.yield($0.state.currentValue! + 10) }
    }
    expectNoDifference(store.currentValue, TestQuery.value + 10)
  }

  @Test("Reports Issue When Accessing Controls When Controller Is Deallocated")
  func reportsIssueWhenAccessingControlsWhenControllerIsDeallocated() async throws {
    final class EvilController<State: OperationState>: OperationController {
      let controls = Lock<OperationControls<State>?>(nil)

      func control(with controls: OperationControls<State>) -> OperationSubscription {
        self.controls.withLock { $0 = controls }
        return .empty
      }
    }

    let controller = EvilController<TestQuery.State>()
    do {
      _ = OperationStore.detached(
        query: TestQuery().controlled(by: controller),
        initialValue: nil
      )
    }

    withKnownIssue {
      _ = controller.controls.withLock { $0?.state }
    } matching: {
      $0.comments.contains(
        .warning(.controllerDeallocatedStoreAccess(stateType: TestQuery.State.self))
      )
    }
  }
}

private enum SomeError: Equatable, Error {
  case a, b
}
