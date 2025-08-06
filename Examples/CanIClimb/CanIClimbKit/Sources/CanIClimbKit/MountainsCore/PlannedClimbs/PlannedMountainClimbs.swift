import Dependencies
import GRDB
import IdentifiedCollections
import OrderedCollections
import StructuredQueriesGRDB
import Tagged
import UUIDV7

// MARK: - PlannedMountainClimbs

public final class PlannedMountainClimbs: Sendable {
  private let database: any DatabaseWriter
  private let api: CanIClimbAPI

  public init(database: any DatabaseWriter, api: CanIClimbAPI = .shared) {
    self.database = database
    self.api = api
  }
}

// MARK: - Shared Instance

extension PlannedMountainClimbs {
  public static let shared: PlannedMountainClimbs = {
    @Dependency(\.defaultDatabase) var database
    return PlannedMountainClimbs(database: database, api: .shared)
  }()
}

// MARK: - PlanClimber

extension PlannedMountainClimbs: Mountain.PlanClimber {
  public func plan(create: Mountain.ClimbPlanCreate) async throws -> Mountain.PlannedClimb {
    let climbRecord = try await self.api.planClimb(CanIClimbAPI.PlanClimbRequest(create: create))
    var alarm = create.alarm?.newScheduleableAlarm()

    // NB: Reassign the alarm to the database record to make equality checks around the localized
    // title work in testing.
    alarm = try await self.database.write { [alarm] db in
      try CachedPlannedClimbRecord.insert { climbRecord }.execute(db)
      guard let alarm else { return nil }
      let alarmRecord = try ScheduleableAlarmRecord.insert { ScheduleableAlarmRecord(alarm: alarm) }
        .returning { $0 }
        .fetchOne(db)!
      try PlannedClimbAlarmRecord.insert {
        PlannedClimbAlarmRecord(
          id: PlannedClimbAlarmRecord.ID(),
          plannedClimbId: climbRecord.id,
          alarmId: alarm.id
        )
      }
      .execute(db)
      return ScheduleableAlarm(record: alarmRecord)
    }

    return Mountain.PlannedClimb(cached: climbRecord, alarm: alarm)
  }

  public func unplanClimbs(ids: OrderedSet<Mountain.PlannedClimb.ID>) async throws {
    try await self.api.unplanClimbs(ids: ids)
    try await self.database.write { db in
      try CachedPlannedClimbRecord.all
        .delete()
        .where { $0.id.in(ids.map { #bind($0) }) }
        .execute(db)
    }
  }
}

// MARK: - ClimbAchiever

extension PlannedMountainClimbs: Mountain.ClimbAchiever {
  public func achieveClimb(id: Mountain.PlannedClimb.ID) async throws {
    let response = try await self.api.achieveClimb(for: id)
    try await self.database.write { db in
      try CachedPlannedClimbRecord.upsert { CachedPlannedClimbRecord.Draft(response) }
        .execute(db)
    }
  }

  public func unachieveClimb(id: Mountain.PlannedClimb.ID) async throws {
    let response = try await self.api.unachieveClimb(for: id)
    try await self.database.write { db in
      try CachedPlannedClimbRecord.upsert { CachedPlannedClimbRecord.Draft(response) }
        .execute(db)
    }
  }
}

// MARK: - PlannedClimbsLoader

extension PlannedMountainClimbs: Mountain.PlannedClimbsLoader {
  public func plannedClimbs(
    for id: Mountain.ID
  ) async throws -> IdentifiedArrayOf<Mountain.PlannedClimb> {
    let climbRecords = try await self.api.plannedClimbs(for: id)
    return try await self.database.write { db in
      try CachedPlannedClimbRecord.all
        .delete()
        .where { $0.id.in(climbRecords.ids.map { #bind($0) }).not() }
        .execute(db)
      try CachedPlannedClimbRecord.upsert {
        climbRecords.map { CachedPlannedClimbRecord.Draft($0) }
      }
      .execute(db)
      return try self.localPlannedClimbs(for: id, in: db)
    }
  }

  public func localPlannedClimbs(
    for id: Mountain.ID
  ) async throws -> IdentifiedArrayOf<Mountain.PlannedClimb> {
    try await self.database.read { try self.localPlannedClimbs(for: id, in: $0) }
  }

  private func localPlannedClimbs(
    for id: Mountain.ID,
    in db: Database
  ) throws -> IdentifiedArrayOf<Mountain.PlannedClimb> {
    let records = try CachedPlannedClimbRecord.all
      .leftJoin(PlannedClimbAlarmRecord.all) { $0.id.eq($1.plannedClimbId) }
      .leftJoin(ScheduleableAlarmRecord.all) { (_, climbAlarm, alarm) in
        climbAlarm.alarmId.eq(alarm.id)
      }
      .where { (climb, _, _) in climb.mountainId.eq(#bind(id)) }
      .select { (climb, _, alarm) in (climb, alarm) }
      .fetchAll(db)
    let climbs = records.map { (climb, alarm) in
      Mountain.PlannedClimb(cached: climb, alarm: alarm.map { ScheduleableAlarm(record: $0) })
    }
    return IdentifiedArray(uniqueElements: climbs)
  }
}
