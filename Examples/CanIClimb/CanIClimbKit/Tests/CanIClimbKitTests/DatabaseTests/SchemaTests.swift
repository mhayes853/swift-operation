import CanIClimbKit
import CustomDump
import Foundation
import SQLiteData
import Tagged
import Testing

@Suite("Schema tests")
struct SchemaTests {
  @Test("Creates Database Successfully")
  func createDatabaseSuccessfully() throws {
    let url = URL.temporaryDirectory.appending(path: "test-\(UUID()).db")

    #expect(throws: Never.self) {
      try canIClimbDatabase(url: url)
    }
    try FileManager.default.removeItem(at: url)
  }

  @Test("Deletes Scheduled Alarm When Associated Mountain Climb Plan Is Deleted")
  func deletesScheduledAlarmWhenAssociatedMountainClimbPlanIsDeleted() async throws {
    let database = try canIClimbDatabase()
    try await database.write { db in
      try CachedPlannedClimbRecord.insert { CachedPlannedClimbRecord(plannedClimb: .mock1) }
        .execute(db)

      let alarm = ScheduleableAlarm(id: ScheduleableAlarm.ID(), title: "Blob", date: .distantFuture)
      try ScheduleableAlarmRecord.insert { ScheduleableAlarmRecord(alarm: alarm) }
        .execute(db)

      let plannedClimbAlarmId = PlannedClimbAlarmRecord.ID()
      try PlannedClimbAlarmRecord.insert {
        PlannedClimbAlarmRecord(
          id: plannedClimbAlarmId,
          plannedClimbId: Mountain.PlannedClimb.mock1.id,
          alarmId: alarm.id
        )
      }
      .execute(db)

      try CachedPlannedClimbRecord.find(#bind(Mountain.PlannedClimb.mock1.id))
        .delete()
        .execute(db)

      let alarmRecord = try ScheduleableAlarmRecord.find(alarm.id).fetchOne(db)
      let plannedClimbAlarmRecord = try PlannedClimbAlarmRecord.find(#bind(plannedClimbAlarmId))
        .fetchOne(db)
      expectNoDifference(alarmRecord, nil)
      expectNoDifference(plannedClimbAlarmRecord, nil)
    }
  }
}
