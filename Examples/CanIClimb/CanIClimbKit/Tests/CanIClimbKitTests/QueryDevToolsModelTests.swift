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
        $0[ApplicationLaunch.ID.self] = QueryAnalysis.mock1.launchId
      }
    )
    func queriesAnalyzesList() async throws {
      @Dependency(\.defaultDatabase) var database

      let launch1 = ApplicationLaunchRecord(
        id: QueryAnalysis.mock1.launchId,
        localizedDeviceName: DeviceInfo.testValue.localizedModelName
      )
      let launch2 = ApplicationLaunchRecord(
        id: QueryAnalysis.mock2.launchId,
        localizedDeviceName: DeviceInfo.testValue.localizedModelName
      )

      try await database.write { db in
        try QueryAnalysisRecord.insert {
          QueryAnalysisRecord.mock1
          QueryAnalysisRecord.mock2
        }
        .execute(db)

        try ApplicationLaunchRecord.insert {
          launch1
          launch2
        }
        .execute(db)
      }

      let model = QueryDevToolsModel()

      try await model.$selectedLaunch.load()
      try await model.$analyzes.load()
      expectNoDifference(model.analyzes, [QueryAnalysis.mock1.queryName: [QueryAnalysis.mock1]])
      expectNoDifference(model.selectedLaunch, launch1)

      model.path.append(.selectLaunch)
      try await model.launchSelected(id: QueryAnalysis.mock2.launchId)
      expectNoDifference(model.analyzes, [QueryAnalysis.mock2.queryName: [QueryAnalysis.mock2]])
      expectNoDifference(model.selectedLaunch, launch2)
      expectNoDifference(model.path, [])
    }
  }
}
