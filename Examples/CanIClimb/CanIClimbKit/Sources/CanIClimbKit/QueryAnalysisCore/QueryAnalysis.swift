import CasePaths
import Tagged
import UUIDV7

// MARK: - QueryAnalysis

public typealias QueryAnalysis = QueryAnalysisRecord

extension QueryAnalysis {
  public typealias ID = Tagged<Self, UUIDV7>
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
