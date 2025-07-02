import CloudKit
import SharingGRDB
import os

extension SyncEngine {
  public static func canIClimb(writer: any DatabaseWriter) throws -> SyncEngine {
    try SyncEngine(
      container: CKContainer(identifier: "iCloud.day.onetask.CanIClimb"),
      database: writer,
      logger: os.Logger(subsystem: "day.onetask.CanIClimb", category: "SyncEngine"),
      tables: [
        SettingsRecord.self,
        MountainClimbGoalRecord.self,
        UserProfileRecord.self,
        InternalMetricsRecord.self
      ]
    )
  }
}
