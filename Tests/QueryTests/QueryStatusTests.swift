import CustomDump
import Foundation
import Query
import QueryTestHelpers
import Testing

@Suite("QueryStatus tests")
struct QueryStatusTests {
  @Test("QueryState Produces Idle Status When Initialized")
  func queryStateProducesIdleStatusWhenInitialized() {
    let store = QueryStore.detached(query: TestQuery(), initialValue: TestQuery.value)
    expectNoDifference(store.status.isIdle, true)
    expectNoDifference(store.status.isSuccessful, false)
    expectNoDifference(store.status.isFailure, false)
    expectNoDifference(store.status.isLoading, false)
  }

  @Test("QueryState Produces Loading Status When Fetching")
  func queryStateProducesLoadingStatusWhenFetching() async throws {
    let query = SleepingQuery()
    let store = QueryStore.detached(query: query, initialValue: "")
    query.didBeginSleeping = {
      store.status.expectLoading()
      query.resume()
    }
    try await store.fetch()
  }

  @Test("QueryState Produces Successful Result Status When Successful")
  func queryStateProducesSuccessfulResultStatusWhenSuccessful() async throws {
    let store = QueryStore.detached(query: TestQuery().defaultValue(TestQuery.value))
    try await store.fetch()
    expectNoDifference(store.status.resultValue, TestQuery.value)
    expectNoDifference(store.status.isSuccessful, true)
    expectNoDifference(store.status.isFailure, false)
    expectNoDifference(store.status.isLoading, false)
    expectNoDifference(store.status.isIdle, false)
  }

  @Test("QueryState Produces Failed Result Status When Unsuccesful")
  func queryStateProducesFailedResultStatusWhenUnsuccessful() async throws {
    let store = QueryStore.detached(query: FailingQuery(), initialValue: nil)
    _ = try? await store.fetch()
    expectNoDifference(store.status.resultValue, nil)
    expectNoDifference(store.status.isSuccessful, false)
    expectNoDifference(store.status.isFailure, true)
    expectNoDifference(store.status.isLoading, false)
    expectNoDifference(store.status.isIdle, false)
  }

  @Test("Fetch Successfully, Then Fetch Again, Is Loading")
  func fetchSuccessfullyThenFetchAgainIsLoading() async throws {
    let query = SleepingQuery()
    let store = QueryStore.detached(query: query.defaultValue("blob"))
    query.didBeginSleeping = {
      store.status.expectLoading()
      query.resume()
    }
    try await store.fetch()
    expectNoDifference(store.status.isSuccessful, true)
    try await store.fetch()
  }

  @Test("Fetch Successfully, Then Fetch Unsuccessfully, Is Failure")
  func fetchSuccessfullyThenFetchUnsuccessfullyIsFailure() async throws {
    let query = FlakeyQuery()
    await query.ensureSuccess(result: "blob")
    let store = QueryStore.detached(query: query.defaultValue("blob"))
    store.context.queryClock = .custom { .distantPast }
    try await store.fetch()
    expectNoDifference(store.status.isSuccessful, true)

    store.context.queryClock = .custom { .distantFuture }
    await query.ensureFailure()
    _ = try? await store.fetch()
    expectNoDifference(store.status.isFailure, true)
  }

  @Test("Fetch Unsuccessfully, Then Fetch Successfully, Is Success")
  func fetchUnsuccessfullyThenFetchSuccessfullyIsSuccess() async throws {
    let query = FlakeyQuery()
    await query.ensureFailure()
    let store = QueryStore.detached(query: query.defaultValue("blob"))
    store.context.queryClock = .custom { .distantPast }
    _ = try? await store.fetch()
    expectNoDifference(store.status.isSuccessful, false)

    store.context.queryClock = .custom { .distantFuture }
    await query.ensureSuccess(result: "blob")
    try await store.fetch()
    expectNoDifference(store.status.isSuccessful, true)
  }

  @Test("Success, Map Status, Returns New Mapped Success Value")
  func successMapStatus() async throws {
    let status = QueryStatus.result(.success(TestQuery.value))
    let newStatus = status.mapSuccess { $0.description }
    expectNoDifference(newStatus.resultValue, TestQuery.value.description)
  }

  @Test("Failure, Map Status, Returns Error")
  func failureMapStatus() async throws {
    let status = QueryStatus<Int>.result(.failure(FailingQuery.SomeError()))
    let newStatus = status.mapSuccess { $0.description }
    expectNoDifference(newStatus.isFailure, true)
  }

  @Test("Idle, Map Status, Returns Idle")
  func idleMapStatus() async throws {
    let status = QueryStatus<Int>.idle
    let newStatus = status.mapSuccess { $0.description }
    expectNoDifference(newStatus.isIdle, true)
  }

  @Test("Loading, Map Status, Returns Loading")
  func loadingMapStatus() async throws {
    let status = QueryStatus<Int>.loading
    let newStatus = status.mapSuccess { $0.description }
    newStatus.expectLoading()
  }

  @Test("Success, FlatMap Status, Returns New Mapped Success Value")
  func successFlatMapStatus() async throws {
    let status = QueryStatus.result(.success(TestQuery.value))
    let newStatus: QueryStatus<String> = status.flatMapSuccess { _ in .idle }
    expectNoDifference(newStatus.isIdle, true)
  }

  @Test("Failure, FlatMap Status, Returns Error")
  func failureFlatMapStatus() async throws {
    let status = QueryStatus<Int>.result(.failure(FailingQuery.SomeError()))
    let newStatus = status.flatMapSuccess { .result(.success($0.description)) }
    expectNoDifference(newStatus.isFailure, true)
  }

  @Test("Idle, FlatMap Status, Returns Idle")
  func idleFlatMapStatus() async throws {
    let status = QueryStatus<Int>.idle
    let newStatus = status.flatMapSuccess { .result(.success($0.description)) }
    expectNoDifference(newStatus.isIdle, true)
  }

  @Test("Loading, FlatMap Status, Returns Loading")
  func loadingFlatMapStatus() async throws {
    let status = QueryStatus<Int>.loading
    let newStatus = status.flatMapSuccess { .result(.success($0.description)) }
    newStatus.expectLoading()
  }

  @Test(
    "Is Cancelled",
    arguments: [
      (QueryStatus<Int>.idle, false),
      (QueryStatus<Int>.loading, false),
      (QueryStatus<Int>.result(.success(1)), false),
      (QueryStatus<Int>.result(.failure(FailingQuery.SomeError())), false),
      (QueryStatus<Int>.result(.failure(CancellationError())), true)
    ]
  )
  func isCancelled(status: QueryStatus<Int>, isCanceled: Bool) {
    expectNoDifference(status.isCancelled, isCanceled)
  }
}

extension QueryStatus {
  fileprivate func expectLoading() {
    expectNoDifference(self.isLoading, true)
    expectNoDifference(self.isIdle, false)
    expectNoDifference(self.isSuccessful, false)
    expectNoDifference(self.isFailure, false)
  }
}
