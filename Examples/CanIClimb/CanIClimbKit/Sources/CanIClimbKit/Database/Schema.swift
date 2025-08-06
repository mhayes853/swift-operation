import Foundation
import IssueReporting
import SharingGRDB
import StructuredQueries
import StructuredQueriesGRDB
import StructuredQueriesTagged
import UUIDV7

// MARK: - InternalMetricsRecord

@Table("InternalMetrics")
public struct InternalMetricsRecord: Hashable, Sendable, SingleRowTable {
  public private(set) var id: UUID = .nil
  public var hasCompletedOnboarding = false

  public init() {}

  public init(hasCompletedOnboarding: Bool = false) {
    self.hasCompletedOnboarding = hasCompletedOnboarding
  }
}

// MARK: - LocalInternalMetricsRecord

@Table("LocalInternalMetrics")
public struct LocalInternalMetricsRecord: Hashable, Sendable, SingleRowTable {
  public private(set) var id: UUID = .nil
  public var hasConnectedHealthKit = false
  public var currentUserId: User.ID?

  public init() {}
}

// MARK: - UserHumanityRecord

@Table("UserHumanity")
public struct UserHumanityRecord: Hashable, Sendable, SingleRowTable {
  public private(set) var id: UUID = .nil

  @Column(as: HumanHeight.JSONRepresentation.self)
  public var height: HumanHeight = .imperial(HumanHeight.Imperial(feet: 5, inches: 8))

  @Column(as: Measurement<UnitMass>.JSONRepresentation.self)
  public var weight: Measurement<UnitMass> = Measurement(value: 150, unit: .pounds)

  public var ageRange: HumanAgeRange = .in20s
  public var gender: HumanGender = .male
  public var activityLevel: HumanActivityLevel = .sedentary
  public var workoutFrequency: HumanWorkoutFrequency = .noDays

  public init() {}

  public init(
    height: HumanHeight = .imperial(HumanHeight.Imperial(feet: 5, inches: 8)),
    weight: Measurement<UnitMass> = Measurement(value: 150, unit: .pounds),
    ageRange: HumanAgeRange = .in20s,
    gender: HumanGender = .male,
    activityLevel: HumanActivityLevel = .sedentary,
    workoutFrequency: HumanWorkoutFrequency = .noDays
  ) {
    self.height = height
    self.weight = weight
    self.ageRange = ageRange
    self.gender = gender
    self.activityLevel = activityLevel
    self.workoutFrequency = workoutFrequency
  }
}

extension UserHumanityRecord {
  public var bmi: HumanBMI {
    HumanBMI(weight: self.weight, height: self.height)
  }
}

// MARK: - CachedMountainRecord

@Table("CachedMountains")
public struct CachedMountainRecord: Hashable, Identifiable, Sendable {
  @Column(as: Mountain.IDRepresentation.self)
  public let id: Mountain.ID
  public var name: String
  public var displayDescription: String
  public var elevationMeters: Double
  public var latitude: Double
  public var longitude: Double

  @Column(as: Mountain.LocationName.JSONRepresentation.self)
  public var locationName: Mountain.LocationName

  public var dateAdded: Date
  public var imageURL: URL
  public var difficulty: Mountain.ClimbingDifficulty

  public init(
    id: Mountain.ID,
    name: String,
    displayDescription: String,
    elevationMeters: Double,
    latitude: Double,
    longitude: Double,
    locationName: Mountain.LocationName,
    dateAdded: Date,
    imageURL: URL,
    difficulty: Mountain.ClimbingDifficulty
  ) {
    self.id = id
    self.name = name
    self.displayDescription = displayDescription
    self.elevationMeters = elevationMeters
    self.latitude = latitude
    self.longitude = longitude
    self.locationName = locationName
    self.dateAdded = dateAdded
    self.imageURL = imageURL
    self.difficulty = difficulty
  }
}

// MARK: - CachedUser

@Table("CachedUsers")
public struct CachedUserRecord: Hashable, Sendable, Identifiable, Codable {
  public let id: User.ID

  @Column(as: User.Name.JSONRepresentation.self)
  public var name: User.Name

  public var subtitle: String

  public init(id: User.ID, name: User.Name, subtitle: String = "") {
    self.id = id
    self.name = name
    self.subtitle = subtitle
  }
}

// MARK: - SettingsRecord

@Table("Settings")
public struct SettingsRecord: Sendable, SingleRowTable {
  public private(set) var id: UUID = .nil
  public var metricPreference: MetricPreference = .imperial
  public var temperaturePreference: TemperaturePreference = .celsius

  public init() {}

  public init(
    metricPreference: SettingsRecord.MetricPreference = .imperial,
    temperaturePreference: SettingsRecord.TemperaturePreference = .celsius
  ) {
    self.metricPreference = metricPreference
    self.temperaturePreference = temperaturePreference
  }
}

extension SettingsRecord {
  public enum MetricPreference: String, QueryBindable, CaseIterable {
    case imperial
    case metric
  }
}

extension SettingsRecord.MetricPreference {
  public var unit: UnitMass {
    switch self {
    case .imperial: .pounds
    case .metric: .kilograms
    }
  }
}

extension SettingsRecord.MetricPreference: CustomLocalizedStringResourceConvertible {
  public var localizedStringResource: LocalizedStringResource {
    switch self {
    case .metric: "Metric (cm, kg)"
    case .imperial: "Imperial (ft, lbs)"
    }
  }
}

extension SettingsRecord {
  public enum TemperaturePreference: String, QueryBindable, CaseIterable {
    case celsius
    case fahrenheit
    case kelvin
  }
}

extension SettingsRecord.TemperaturePreference: CustomLocalizedStringResourceConvertible {
  public var localizedStringResource: LocalizedStringResource {
    switch self {
    case .celsius: "Celsius"
    case .fahrenheit: "Fahrenheit"
    case .kelvin: "Kelvin"
    }
  }
}

// MARK: - MountainPlannedClimbRecord

@Table("CachedPlannedClimbs")
public struct CachedPlannedClimbRecord: Hashable, Sendable, Codable, Identifiable {
  @Column(as: Mountain.PlannedClimb.IDRepresentation.self)
  public let id: Mountain.PlannedClimb.ID

  @Column(as: Mountain.IDRepresentation.self)
  public let mountainId: Mountain.ID

  public var targetDate: Date
  public var achievedDate: Date?

  public init(
    id: Mountain.PlannedClimb.ID,
    mountainId: Mountain.ID,
    targetDate: Date,
    achievedDate: Date?
  ) {
    self.id = id
    self.mountainId = mountainId
    self.targetDate = targetDate
    self.achievedDate = achievedDate
  }
}

// MARK: - QueryAnalysisRecord

@Table("QueryAnalysis")
public struct QueryAnalysisRecord: Hashable, Sendable, Identifiable {
  public let id: QueryAnalysis.ID
  public let launchId: ApplicationLaunch.ID
  public var queryRetryAttempt: Int
  public var queryRuntimeDuration: TimeInterval
  public var queryName: QueryAnalysis.QueryName
  public var queryPathDescription: String

  @Column(as: [QueryAnalysis.DataResult].JSONRepresentation.self)
  public var yieldedQueryDataResults: [QueryAnalysis.DataResult]

  @Column(as: QueryAnalysis.DataResult.JSONRepresentation.self)
  public var queryDataResult: QueryAnalysis.DataResult

  public init(
    id: QueryAnalysis.ID,
    launchId: ApplicationLaunch.ID,
    queryRetryAttempt: Int,
    queryRuntimeDuration: TimeInterval,
    queryName: QueryAnalysis.QueryName,
    queryPathDescription: String,
    yieldedQueryDataResults: [QueryAnalysis.DataResult],
    queryDataResult: QueryAnalysis.DataResult
  ) {
    self.id = id
    self.launchId = launchId
    self.queryRetryAttempt = queryRetryAttempt
    self.queryRuntimeDuration = queryRuntimeDuration
    self.queryName = queryName
    self.queryPathDescription = queryPathDescription
    self.yieldedQueryDataResults = yieldedQueryDataResults
    self.queryDataResult = queryDataResult
  }
}

// MARK: - ApplicationLaunchRecord

@Table("ApplicationLaunches")
public struct ApplicationLaunchRecord: Hashable, Sendable, Identifiable {
  public let id: ApplicationLaunch.ID
  public var localizedDeviceName: String

  public init(id: ApplicationLaunch.ID, localizedDeviceName: String) {
    self.id = id
    self.localizedDeviceName = localizedDeviceName
  }
}

// MARK: - ScheduleableAlarmRecord

@Table("ScheduleableAlarms")
public struct ScheduleableAlarmRecord: Equatable, Sendable, Identifiable {
  public let id: ScheduleableAlarm.ID

  @Column(as: LocalizedStringResource.JSONRepresentation.self)
  public var title: LocalizedStringResource

  public var date: Date
  public var isScheduled: Bool

  public init(
    id: ScheduleableAlarm.ID,
    title: LocalizedStringResource,
    date: Date,
    isScheduled: Bool
  ) {
    self.id = id
    self.title = title
    self.date = date
    self.isScheduled = isScheduled
  }
}

// MARK: - PlannedClimbAlarmRecord

@Table("PlannedClimbAlarms")
public struct PlannedClimbAlarmRecord: Hashable, Sendable, Codable {
  public var id: ID

  @Column(as: Mountain.PlannedClimb.IDRepresentation.self)
  public var plannedClimbId: Mountain.PlannedClimb.ID

  public var alarmId: ScheduleableAlarm.ID

  public init(
    id: ID,
    plannedClimbId: Mountain.PlannedClimb.ID,
    alarmId: ScheduleableAlarm.ID
  ) {
    self.id = id
    self.plannedClimbId = plannedClimbId
    self.alarmId = alarmId
  }
}

extension PlannedClimbAlarmRecord {
  public typealias ID = Tagged<PlannedClimbAlarmRecord, UUIDV7>
  public typealias IDRepresentation = Tagged<PlannedClimbAlarmRecord, UUIDV7.BytesRepresentation>
}

// MARK: - Can I Climb Database

public func canIClimbDatabase(url: URL? = nil) throws -> any DatabaseWriter {
  if let url {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
  }
  var configuration = Configuration()
  configuration.foreignKeysEnabled = isTesting
  configuration.prepareDatabase { db in
    db.add(function: .localizedStandardContains)
    db.addUUIDV7Functions()
    #if DEBUG
      db.trace(options: .profile) {
        print("\($0.expandedDescription)")
      }
    #endif
  }

  let writer = try writer(for: url, configuration: configuration)
  var migrator = DatabaseMigrator()
  #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
  #endif
  migrator.registerV1()
  try migrator.migrate(writer)

  try writer.write { db in
    try createTriggers(in: db)
  }
  return writer
}

private func writer(for url: URL?, configuration: Configuration) throws -> any DatabaseWriter {
  if let url {
    try DatabasePool(path: url.path, configuration: configuration)
  } else {
    try DatabaseQueue(configuration: configuration)
  }
}

private func createTriggers(in db: Database) throws {
  try PlannedClimbAlarmRecord.createTemporaryTrigger(
    after: .delete(forEachRow: { old in ScheduleableAlarmRecord.all.find(old.alarmId).delete() })
  )
  .execute(db)
}

// MARK: - Migrations

extension DatabaseMigrator {
  fileprivate mutating func registerV1() {
    self.registerMigration("create internal metrics table") { db in
      try #sql(
        """
        CREATE TABLE IF NOT EXISTS InternalMetrics (
         \(raw: singleRowTablePrimaryKeyColumnSQL),
          hasCompletedOnboarding BOOLEAN NOT NULL DEFAULT FALSE
        );
        """,
        as: Void.self
      )
      .execute(db)
    }
    self.registerMigration("create user humanity table") { db in
      try #sql(
        """
        CREATE TABLE IF NOT EXISTS UserHumanity (
         \(raw: singleRowTablePrimaryKeyColumnSQL),
          height BLOB NOT NULL,
          weight BLOB NOT NULL,
          ageRange TEXT NOT NULL,
          gender TEXT NOT NULL,
          activityLevel TEXT NOT NULL,
          workoutFrequency TEXT NOT NULL
        );
        """,
        as: Void.self
      )
      .execute(db)
    }
    self.registerMigration("create mountains cache table") { db in
      try #sql(
        """
        CREATE TABLE IF NOT EXISTS CachedMountains (
          id BLOB PRIMARY KEY,
          name TEXT NOT NULL,
          displayDescription TEXT NOT NULL,
          elevationMeters DOUBLE NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          locationName TEXT NOT NULL,
          difficulty DOUBLE NOT NULL,
          imageURL TEXT NOT NULL,
          dateAdded TIMESTAMP NOT NULL
        );
        """,
        as: Void.self
      )
      .execute(db)
    }
    self.registerMigration("create settings table") { db in
      try #sql(
        """
        CREATE TABLE IF NOT EXISTS Settings (
          \(raw: singleRowTablePrimaryKeyColumnSQL),
          metricPreference TEXT NOT NULL,
          temperaturePreference TEXT NOT NULL
        );
        """,
        as: Void.self
      )
      .execute(db)
    }
    self.registerMigration("create mountain climb goals table") { db in
      try #sql(
        """
        CREATE TABLE IF NOT EXISTS CachedPlannedClimbs (
          id BLOB PRIMARY KEY,
          mountainId BLOB NOT NULL,
          targetDate TIMESTAMP NOT NULL,
          achievedDate TIMESTAMP
        );
        """,
        as: Void.self
      )
      .execute(db)
    }
    self.registerMigration("create local internal metrics table") { db in
      try #sql(
        """
        CREATE TABLE IF NOT EXISTS LocalInternalMetrics (
          \(raw: singleRowTablePrimaryKeyColumnSQL),
          hasConnectedHealthKit BOOLEAN NOT NULL,
          currentUserId TEXT
        );
        """,
        as: Void.self
      )
      .execute(db)
    }
    self.registerMigration("create cached users table") { db in
      try #sql(
        """
        CREATE TABLE IF NOT EXISTS CachedUsers (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          subtitle TEXT NOT NULL
        );
        """,
        as: Void.self
      )
      .execute(db)
    }
    self.registerMigration("create query analysis table") { db in
      try #sql(
        """
        CREATE TABLE IF NOT EXISTS QueryAnalysis (
          id TEXT PRIMARY KEY,
          launchId BLOB NOT NULL,
          queryRetryAttempt INTEGER NOT NULL,
          queryRuntimeDuration REAL NOT NULL,
          queryName TEXT NOT NULL,
          queryPathDescription TEXT NOT NULL,
          yieldedQueryDataResults TEXT NOT NULL,
          queryDataResult TEXT NOT NULL
        );
        """,
        as: Void.self
      )
      .execute(db)
    }
    self.registerMigration("create application launches table") { db in
      try #sql(
        """
        CREATE TABLE IF NOT EXISTS ApplicationLaunches (
          id TEXT PRIMARY KEY,
          localizedDeviceName TEXT NOT NULL
        );
        """,
        as: Void.self
      )
      .execute(db)
    }
    self.registerMigration("create alarms table") { db in
      try #sql(
        """
        CREATE TABLE IF NOT EXISTS ScheduleableAlarms (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          date REAL NOT NULL,
          isScheduled BOOLEAN NOT NULL
        );
        """,
        as: Void.self
      )
      .execute(db)
    }
    self.registerMigration("create planned climb alarms table") { db in
      try #sql(
        """
        CREATE TABLE IF NOT EXISTS PlannedClimbAlarms (
          id TEXT NOT NULL,
          plannedClimbId BLOB NOT NULL REFERENCES CachedPlannedClimbs(id) ON DELETE CASCADE,
          alarmId TEXT NOT NULL REFERENCES ScheduleableAlarms(id) ON DELETE CASCADE,
          PRIMARY KEY (plannedClimbID, alarmId)
        );
        """,
        as: Void.self
      )
      .execute(db)
    }
  }
}

private let singleRowTablePrimaryKeyColumnSQL = "id TEXT PRIMARY KEY CHECK (id = '\(UUID.nil)')"
