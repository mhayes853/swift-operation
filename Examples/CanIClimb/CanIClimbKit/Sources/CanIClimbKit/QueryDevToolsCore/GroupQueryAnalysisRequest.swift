import IdentifiedCollections
import OrderedCollections
import SharingGRDB
import Tagged

// MARK: - GroupQueryAnalysisRequest

public struct GroupQueryAnalysisRequest: Hashable, Sendable {
  private let launchId: ApplicationLaunch.ID

  public init(launchId: ApplicationLaunch.ID) {
    self.launchId = launchId
  }
}

// MARK: - FetchKeyRequest

extension GroupQueryAnalysisRequest: FetchKeyRequest {
  public typealias Value = OrderedDictionary<
    QueryAnalysis.QueryName, IdentifiedArrayOf<QueryAnalysis>
  >

  public func fetch(_ db: Database) throws -> Value {
    try QueryAnalysisRecord.all
      .where { $0.launchId.eq(#bind(self.launchId)) }
      .order(by: \.id)
      .fetchAll(db)
      .reduce(into: Value()) { value, analysis in
        value[analysis.queryName, default: []].append(analysis)
      }
  }
}
