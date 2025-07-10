import CloudKit
import SharingGRDB
import os

// MARK: - SyncEngine

extension SyncEngine {
  public static func canIClimb(writer: any DatabaseWriter) throws -> SyncEngine {
    try SyncEngine(
      container: .canIClimb,
      database: writer,
      logger: os.Logger(subsystem: "day.onetask.CanIClimb", category: "SyncEngine"),
      tables: [
        MountainClimbGoalRecord.self,
        UserHumanityRecord.self
      ],
      privateTables: [
        SettingsRecord.self,
        InternalMetricsRecord.self
      ]
    )
  }
}

// MARK: - CKContainer

extension CKContainer {
  public static let canIClimb = CKContainer(identifier: "iCloud.day.onetask.CanIClimb")
}
