import CanIClimbKit
import CustomDump
import SharingGRDB
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("QueryDevToolsModel tests")
  struct QueryDevToolsModelTests {
    @Test(
      "Queries Analyzes List",
      .dependencies {
        $0[ApplicationLaunchID.self] = QueryAnalysis.mock1.launchId
      }
    )
    func queriesAnalyzesList() async throws {
      @Dependency(\.defaultDatabase) var database

      try await database.write { db in
        try QueryAnalysisRecord.insert {
          QueryAnalysisRecord.mock1
          QueryAnalysisRecord.mock2
        }
        .execute(db)
      }

      let model = QueryDevToolsModel()

      try await model.$analyzes.load()
      expectNoDifference(model.analyzes, [QueryAnalysis.mock1.queryName: [QueryAnalysis.mock1]])

      try await model.launchSelected(id: QueryAnalysis.mock2.launchId)
      expectNoDifference(model.analyzes, [QueryAnalysis.mock2.queryName: [QueryAnalysis.mock2]])
    }
  }
}
