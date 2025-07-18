import CasePaths
import Tagged
import UUIDV7

// MARK: - QueryAnalysis

public typealias QueryAnalysis = QueryAnalysisRecord

extension QueryAnalysis {
  public typealias ID = Tagged<Self, UUIDV7>
  public typealias QueryName = Tagged<Self, String>
}

// MARK: - DataResult

extension QueryAnalysis {
  public struct DataResult: Hashable, Sendable, Codable {
    public let didSucceed: Bool
    public let dataDescription: String

    public init(didSucceed: Bool, dataDescription: String) {
      self.didSucceed = didSucceed
      self.dataDescription = dataDescription
    }
  }
}

extension QueryAnalysis.DataResult {
  public init<T>(result: Result<T, any Error>) {
    self.didSucceed = result.is(\.success)
    switch result {
    case .success(let value):
      self.dataDescription = String(describing: value)
    case .failure(let error):
      self.dataDescription = String(describing: error)
    }
  }
}

// MARK: - Mock Data

extension QueryAnalysis {
  public static let mock1 = Self(
    id: ID(),
    launchId: ApplicationLaunchID(),
    queryRetryAttempt: 0,
    queryRuntimeDuration: 1,
    queryName: "Mock1",
    queryPathDescription: "QueryPath([\"mock1\"])",
    yieldedQueryDataResults: [],
    queryDataResult: DataResult(didSucceed: true, dataDescription: "Something(count: 10)")
  )

  public static let mock2 = Self(
    id: ID(),
    launchId: ApplicationLaunchID(),
    queryRetryAttempt: 0,
    queryRuntimeDuration: 1,
    queryName: "Mock2",
    queryPathDescription: "QueryPath([\"mock2\"])",
    yieldedQueryDataResults: [],
    queryDataResult: DataResult(didSucceed: true, dataDescription: "Something(count: 20)")
  )
}
