import ConcurrencyExtras
import Dependencies
import Foundation
import IssueReporting
import Operation
import Synchronization
import UUIDV7

// MARK: - OperationModifier

extension StatefulOperationRequest where Self: Sendable {
  public func analyzed() -> ModifiedOperation<Self, _AnalysisModifier<Self>> {
    self.modifier(_AnalysisModifier())
  }
}

public struct _AnalysisModifier<
  Operation: StatefulOperationRequest & Sendable
>: OperationModifier, Sendable {
  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using query: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.continuousClock) var clock
    @Dependency(ApplicationLaunch.ID.self) var launchId
    @Dependency(\.uuidv7) var uuidv7

    let yields = Mutex([Result<Operation.Value, Operation.Failure>]())
    let continuation = OperationContinuation<Operation.Value, Operation.Failure> {
      result,
      context in
      yields.withLock { $0.append(result) }
      continuation.yield(with: result, using: context)
    }

    var result: Result<Operation.Value, Operation.Failure>!
    let time = await clock.measure {
      result = await Result { @Sendable () async throws(Operation.Failure) -> Operation.Value in
        try await query.run(isolation: isolation, in: context, with: continuation)
      }
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

    await withErrorReporting {
      try await database.write {
        try OperationAnalysisRecord.insert { OperationAnalysisRecord.Draft(analysis) }.execute($0)
      }
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
  public init<Operation: StatefulOperationRequest>(
    id: OperationAnalysis.ID,
    launchId: ApplicationLaunch.ID,
    operation: Operation,
    operationRetryAttempt: Int?,
    operationRuntimeDuration: Duration,
    yieldedResults: [Result<Operation.Value, Operation.Failure>],
    finalResult: Result<Operation.Value, Operation.Failure>
  ) {
    self.init(
      id: id,
      launchId: launchId,
      operationRetryAttempt: operationRetryAttempt,
      operationRuntimeDuration: TimeInterval(duration: operationRuntimeDuration),
      operationName: operation.analysisName,
      operationPathDescription: operation.path.description,
      yieldedOperationDataResults: yieldedResults.map { DataResult(result: $0.mapError { $0 }) },
      operationDataResult: DataResult(result: finalResult.mapError { $0 })
    )
  }
}
