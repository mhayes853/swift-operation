import ConcurrencyExtras
import Dependencies
import Foundation
import Query
import Synchronization
import UUIDV7

// MARK: - QueryModifier

extension QueryRequest {
  public func analyzed() -> ModifiedQuery<Self, _AnalysisModifier<Self>> {
    self.modifier(_AnalysisModifier())
  }
}

public struct _AnalysisModifier<Query: QueryRequest>: QueryModifier {
  public func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.continuousClock) var clock
    @Dependency(ApplicationLaunchIDKey.self) var launchId
    @Dependency(\.uuidv7) var uuidv7

    let yields = Mutex([Result<Query.Value, any Error>]())
    let continuation = QueryContinuation<Query.Value> { result, context in
      yields.withLock { $0.append(result) }
      continuation.yield(with: result, using: context)
    }

    var result: Result<Query.Value, any Error>!
    let time = await clock.measure {
      result = await Result { try await query.fetch(in: context, with: continuation) }
    }

    let analysis = QueryAnalysis(
      id: QueryAnalysis.ID(uuidv7()),
      launchId: launchId,
      query: query,
      queryRetryAttempt: context.queryRetryIndex,
      queryRuntimeDuration: time,
      yieldedResults: yields.withLock { $0 },
      finalResult: result
    )
    try await database.write {
      try QueryAnalysisRecord.insert { QueryAnalysisRecord.Draft(analysis) }.execute($0)
    }

    return try result.get()
  }
}

// MARK: - Helper Initializer

extension QueryRequest {
  public var analysisName: QueryAnalysis.QueryName {
    QueryAnalysis.QueryName(self._debugTypeName)
  }
}

extension QueryAnalysis {
  public init<Query: QueryRequest>(
    id: QueryAnalysis.ID,
    launchId: ApplicationLaunchID,
    query: Query,
    queryRetryAttempt: Int,
    queryRuntimeDuration: Duration,
    yieldedResults: [Result<Query.Value, any Error>],
    finalResult: Result<Query.Value, any Error>
  ) {
    self.init(
      id: id,
      launchId: launchId,
      queryRetryAttempt: queryRetryAttempt,
      queryRuntimeDuration: TimeInterval(duration: queryRuntimeDuration),
      queryName: query.analysisName,
      queryPathDescription: query.path.description,
      yieldedQueryDataResults: yieldedResults.map { DataResult(result: $0) },
      queryDataResult: DataResult.init(result: finalResult)
    )
  }
}
