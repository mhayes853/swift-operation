import CanIClimbKit
import CustomDump
import SQLiteData
import Testing

@Suite("HealthPermissions tests")
struct HealthPermissionsTests {
  private let database = try! canIClimbDatabase()

  @Test("Updates Has Connected To HealthKit When Successful")
  func updateHasConnectedToHealthKitWhenSuccessful() async throws {
    let requester = HealthPermissions.MockRequester()
    let permissions = HealthPermissions(database: self.database, requester: requester)

    var record = try await self.database.read { LocalInternalMetricsRecord.find(in: $0) }
    expectNoDifference(record.hasConnectedHealthKit, false)

    try await permissions.request()

    record = try await self.database.read { LocalInternalMetricsRecord.find(in: $0) }
    expectNoDifference(record.hasConnectedHealthKit, true)
  }

  @Test("Does Not Update HealthKit Connection Status When Failed")
  func doesNotUpdateHealthKitConnectionStatusWhenFailed() async throws {
    var requester = HealthPermissions.MockRequester()
    requester.shouldFail = true
    let permissions = HealthPermissions(database: self.database, requester: requester)

    try? await permissions.request()

    let record = try await self.database.read { LocalInternalMetricsRecord.find(in: $0) }
    expectNoDifference(record.hasConnectedHealthKit, false)
  }
}
