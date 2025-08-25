import ConcurrencyExtras
import Dependencies
import Foundation
import Operation
import Synchronization
import UUIDV7

// MARK: - OperationModifier

extension OperationRequest {
  public func analyzed() -> ModifiedOperation<Self, _AnalysisModifier<Self>> {
    self.modifier(_AnalysisModifier())
  }
}

public struct _AnalysisModifier<Query: QueryRequest>: OperationModifier {
  public func fetch(
    in context: OperationContext,
    using query: Query,
    with continuation: OperationContinuation<Query.Value>
  ) async throws -> Query.Value {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.continuousClock) var clock
    @Dependency(ApplicationLaunch.ID.self) var launchId
    @Dependency(\.uuidv7) var uuidv7

    let yields = Mutex([Result<Query.Value, any Error>]())
    let continuation = OperationContinuation<Query.Value> { result, context in
      yields.withLock { $0.append(result) }
      continuation.yield(with: result, using: context)
    }

    var result: Result<Query.Value, any Error>!
    let time = await clock.measure {
      result = await Result { try await query.fetch(in: context, with: continuation) }
    }

    let analysis = OperationAnalysis(
      id: OperationAnalysis.ID(uuidv7()),
      launchId: launchId,
      operation: query,
      operationRetryAttempt: context.operationRetryIndex,
      operationRuntimeDuration: time,
      yieldedResults: yields.withLock { $0 },
      finalResult: result
    )
    try await database.write {
      try OperationAnalysisRecord.insert { OperationAnalysisRecord.Draft(analysis) }.execute($0)
    }

    return try result.get()
  }
}

// MARK: - Helper Initializer

extension OperationRequest {
  public var analysisName: OperationAnalysis.OperationName {
    OperationAnalysis.OperationName(self._debugTypeName)
  }
}

extension OperationAnalysis {
  public init<Query: QueryRequest>(
    id: OperationAnalysis.ID,
    launchId: ApplicationLaunch.ID,
    operation: Query,
    operationRetryAttempt: Int,
    operationRuntimeDuration: Duration,
    yieldedResults: [Result<Query.Value, any Error>],
    finalResult: Result<Query.Value, any Error>
  ) {
    self.init(
      id: id,
      launchId: launchId,
      operationRetryAttempt: operationRetryAttempt,
      operationRuntimeDuration: TimeInterval(duration: operationRuntimeDuration),
      operationName: operation.analysisName,
      operationPathDescription: operation.path.description,
      yieldedOperationDataResults: yieldedResults.map { DataResult(result: $0) },
      operationDataResult: DataResult(result: finalResult)
    )
  }
}
