import CloudKit
import SQLiteData
import UUIDV7
import os

// MARK: - SyncEngine

extension SyncEngine {
  public static func canIClimb(writer: any DatabaseWriter) throws -> SyncEngine {
    try SyncEngine(
      for: writer,
      tables: UserHumanityRecord.self,
      SettingsRecord.self,
      InternalMetricsRecord.self,
      ScheduleableAlarmRecord.self,
      OperationAnalysisRecord.self,
      ApplicationLaunchRecord.self,
      PlannedClimbAlarmRecord.self,
      CachedPlannedClimbRecord.self,
      CachedMountainRecord.self,
      containerIdentifier: CKContainer.canIClimb.containerIdentifier
    )
  }
}

// MARK: - CKContainer

extension CKContainer {
  public static let canIClimb = CKContainer(identifier: "iCloud.day.onetask.CanIClimb")
}
