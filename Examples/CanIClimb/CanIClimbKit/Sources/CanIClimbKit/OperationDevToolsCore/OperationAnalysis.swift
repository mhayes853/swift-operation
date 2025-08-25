import CasePaths
import Tagged
import UUIDV7

// MARK: - OperationAnalysis

public typealias OperationAnalysis = OperationAnalysisRecord

extension OperationAnalysis {
  public typealias ID = Tagged<Self, UUIDV7>
  public typealias OperationName = Tagged<Self, String>
}

// MARK: - DataResult

extension OperationAnalysis {
  public struct DataResult: Hashable, Sendable, Codable {
    public let didSucceed: Bool
    public let dataDescription: String

    public init(didSucceed: Bool, dataDescription: String) {
      self.didSucceed = didSucceed
      self.dataDescription = dataDescription
    }

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
}

// MARK: - Mock Data

extension OperationAnalysis {
  public static let mock1 = Self(
    id: ID(),
    launchId: ApplicationLaunch.ID(),
    operationRetryAttempt: 0,
    operationRuntimeDuration: 1,
    operationName: "Mock1",
    operationPathDescription: "OperationPath([\"mock1\"])",
    yieldedOperationDataResults: [],
    operationDataResult: DataResult(didSucceed: true, dataDescription: "Something(count: 10)")
  )

  public static let mock2 = Self(
    id: ID(),
    launchId: ApplicationLaunch.ID(),
    operationRetryAttempt: 0,
    operationRuntimeDuration: 1,
    operationName: "Mock2",
    operationPathDescription: "OperationPath([\"mock2\"])",
    yieldedOperationDataResults: [],
    operationDataResult: DataResult(didSucceed: true, dataDescription: "Something(count: 20)")
  )
}
