import CanIClimbKit
import CustomDump
import Foundation
import Operation
import SharingGRDB
import Testing
import UUIDV7

extension DependenciesTestSuite {
  @Suite(
    "AnalysisQuery tests",
    .dependencies {
      $0.continuousClock = MockMeasurementClock(stride: .testDuration)
      $0.uuidv7 = .incrementing(from: 0)
    }
  )
  struct AnalysisQueryTests {
    @Test("Analyzes Successful Query Run")
    func analyzeSuccessfulQueryRun() async throws {
      @Dependency(ApplicationLaunch.ID.self) var launchId

      let query = TestQuery().analyzed()
      let store = OperationStore.detached(query: query, initialValue: nil)
      let value = try await store.fetch()
      expectNoDifference(value, TestQuery.value)

      try await expectGroupedAnalyses([
        query.analysisName: [
          OperationAnalysis(
            id: OperationAnalysis.ID(UUIDV7(timeIntervalSince1970: 0, 0)),
            launchId: launchId,
            operation: query,
            operationRetryAttempt: 0,
            operationRuntimeDuration: .testDuration,
            yieldedResults: [],
            finalResult: .success(TestQuery.value)
          )
        ]
      ])
    }

    @Test("Analyzes Failed Query Run")
    func analyzeFailedQueryRun() async throws {
      @Dependency(ApplicationLaunch.ID.self) var launchId

      let query = TestQuery(shouldFail: true).analyzed().retry(limit: 1).delayer(.noDelay)
      let store = OperationStore.detached(query: query, initialValue: nil)
      _ = try? await store.fetch()

      try await expectGroupedAnalyses([
        query.analysisName: [
          OperationAnalysis(
            id: OperationAnalysis.ID(UUIDV7(timeIntervalSince1970: 0, 0)),
            launchId: launchId,
            operation: query,
            operationRetryAttempt: 0,
            operationRuntimeDuration: .testDuration,
            yieldedResults: [],
            finalResult: .failure(SomeError())
          ),
          OperationAnalysis(
            id: OperationAnalysis.ID(UUIDV7(timeIntervalSince1970: 0, 1)),
            launchId: launchId,
            operation: query,
            operationRetryAttempt: 1,
            operationRuntimeDuration: .testDuration,
            yieldedResults: [],
            finalResult: .failure(SomeError())
          )
        ]
      ])
    }

    @Test("Analyzes Query Run With Continuation Yields")
    func analyzesQueryRunWithContinuationYields() async throws {
      @Dependency(ApplicationLaunch.ID.self) var launchId

      let query = TestQuery(yieldCount: 2).analyzed()
      let store = OperationStore.detached(query: query, initialValue: nil)
      try await store.fetch()

      try await expectGroupedAnalyses([
        query.analysisName: [
          OperationAnalysis(
            id: OperationAnalysis.ID(UUIDV7(timeIntervalSince1970: 0, 0)),
            launchId: launchId,
            operation: query,
            operationRetryAttempt: 0,
            operationRuntimeDuration: .testDuration,
            yieldedResults: [.success(TestQuery.value), .success(TestQuery.value)],
            finalResult: .success(TestQuery.value)
          )
        ]
      ])
    }

    @Test("Analyzes Queries On a Per Launch Basis")
    func analyzesQueriesOnPerLaunchBasis() async throws {
      @Dependency(ApplicationLaunch.ID.self) var launchId1
      let launchId2 = ApplicationLaunch.ID()

      let query = TestQuery(yieldCount: 1).analyzed()
      let store = OperationStore.detached(query: query, initialValue: nil)
      try await store.fetch()
      try await withDependencies {
        $0[ApplicationLaunch.ID.self] = launchId2
      } operation: {
        try await store.fetch()
      }

      try await expectGroupedAnalyses(
        for: launchId1,
        [
          query.analysisName: [
            OperationAnalysis(
              id: OperationAnalysis.ID(UUIDV7(timeIntervalSince1970: 0, 0)),
              launchId: launchId1,
              operation: query,
              operationRetryAttempt: 0,
              operationRuntimeDuration: .testDuration,
              yieldedResults: [.success(TestQuery.value)],
              finalResult: .success(TestQuery.value)
            )
          ]
        ]
      )
      try await expectGroupedAnalyses(
        for: launchId2,
        [
          query.analysisName: [
            OperationAnalysis(
              id: OperationAnalysis.ID(UUIDV7(timeIntervalSince1970: 0, 1)),
              launchId: launchId2,
              operation: query,
              operationRetryAttempt: 0,
              operationRuntimeDuration: .testDuration,
              yieldedResults: [.success(TestQuery.value)],
              finalResult: .success(TestQuery.value)
            )
          ]
        ]
      )
    }

    @Test("Groups Analyses By Query Name")
    func groupsAnalysesByOperationName() async throws {
      @Dependency(ApplicationLaunch.ID.self) var launchId

      let query = TestQuery().analyzed()
      let query2 = TestQuery2().analyzed()

      let store = OperationStore.detached(query: query, initialValue: nil)
      let store2 = OperationStore.detached(query: query2, initialValue: nil)
      try await store.fetch()
      try await store2.fetch()

      try await expectGroupedAnalyses([
        query.analysisName: [
          OperationAnalysis(
            id: OperationAnalysis.ID(UUIDV7(timeIntervalSince1970: 0, 0)),
            launchId: launchId,
            operation: query,
            operationRetryAttempt: 0,
            operationRuntimeDuration: .testDuration,
            yieldedResults: [],
            finalResult: .success(TestQuery.value)
          )
        ],
        query2.analysisName: [
          OperationAnalysis(
            id: OperationAnalysis.ID(UUIDV7(timeIntervalSince1970: 0, 1)),
            launchId: launchId,
            operation: query2,
            operationRetryAttempt: 0,
            operationRuntimeDuration: .testDuration,
            yieldedResults: [],
            finalResult: .success(TestQuery2.value)
          )
        ]
      ])
    }
  }
}

private func expectGroupedAnalyses(
  for launchId: ApplicationLaunch.ID? = nil,
  _ value: GroupOperationAnalysisRequest.Value
) async throws {
  @Dependency(ApplicationLaunch.ID.self) var defaultLaunchId
  @Dependency(\.defaultDatabase) var database

  let launchId = launchId ?? defaultLaunchId
  let request = GroupOperationAnalysisRequest(launchId: launchId)
  let grouped = try await database.read { try request.fetch($0) }
  expectNoDifference(grouped, value)
}

private struct TestQuery: QueryRequest, Hashable {
  static let value = 0

  var yieldCount = 0
  var shouldFail = false

  func fetch(
    in context: OperationContext,
    with continuation: OperationContinuation<Int>
  ) async throws -> Int {
    if self.shouldFail {
      throw SomeError()
    }
    for _ in 0..<self.yieldCount {
      continuation.yield(Self.value)
    }
    return Self.value
  }
}

private struct TestQuery2: QueryRequest, Hashable {
  static let value = 400

  func fetch(
    in context: OperationContext,
    with continuation: OperationContinuation<Int>
  ) async throws -> Int {
    Self.value
  }
}

private struct SomeError: Error {}

extension Duration {
  fileprivate static let testDuration = Self.seconds(1)
}
