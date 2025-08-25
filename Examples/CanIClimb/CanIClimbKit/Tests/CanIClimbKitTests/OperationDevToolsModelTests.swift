import CanIClimbKit
import CustomDump
import SharingGRDB
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("OperationDevToolsModel tests")
  struct OperationDevToolsModelTests {
    @Test(
      "Queries Analyzes List",
      .dependencies {
        $0[ApplicationLaunch.ID.self] = OperationAnalysis.mock1.launchId
      }
    )
    func queriesAnalyzesList() async throws {
      @Dependency(\.defaultDatabase) var database

      let launch1 = ApplicationLaunchRecord(
        id: OperationAnalysis.mock1.launchId,
        localizedDeviceName: DeviceInfo.testValue.localizedModelName
      )
      let launch2 = ApplicationLaunchRecord(
        id: OperationAnalysis.mock2.launchId,
        localizedDeviceName: DeviceInfo.testValue.localizedModelName
      )

      try await database.write { db in
        try OperationAnalysisRecord.insert {
          OperationAnalysisRecord.mock1
          OperationAnalysisRecord.mock2
        }
        .execute(db)

        try ApplicationLaunchRecord.insert {
          launch1
          launch2
        }
        .execute(db)
      }

      let model = OperationDevToolsModel()

      try await model.$selectedLaunch.load()
      try await model.$analyzes.load()
      expectNoDifference(
        model.analyzes,
        [OperationAnalysis.mock1.operationName: [OperationAnalysis.mock1]]
      )
      expectNoDifference(model.selectedLaunch, launch1)

      model.path.append(.selectLaunch)
      try await model.launchSelected(id: OperationAnalysis.mock2.launchId)
      expectNoDifference(
        model.analyzes,
        [OperationAnalysis.mock2.operationName: [OperationAnalysis.mock2]]
      )
      expectNoDifference(model.selectedLaunch, launch2)
      expectNoDifference(model.path, [])
    }
  }
}
