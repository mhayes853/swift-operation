import IdentifiedCollections
import OrderedCollections
import SharingGRDB
import Tagged

public struct GroupOperationAnalysisRequest: FetchKeyRequest {
  private let launchId: ApplicationLaunch.ID

  public init(launchId: ApplicationLaunch.ID) {
    self.launchId = launchId
  }

  public typealias Value = OrderedDictionary<
    OperationAnalysis.OperationName, IdentifiedArrayOf<OperationAnalysis>
  >

  public func fetch(_ db: Database) throws -> Value {
    try OperationAnalysisRecord.all
      .where { $0.launchId.eq(#bind(self.launchId)) }
      .order(by: \.id)
      .fetchAll(db)
      .reduce(into: Value()) { value, analysis in
        value[analysis.operationName, default: []].append(analysis)
      }
  }
}
