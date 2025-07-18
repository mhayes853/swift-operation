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

// MARK: - CachedMountainRecord

@Table("CachedMountains")
public struct CachedMountainRecord {
  @Column(as: Mountain.IDRepresentation.self)
  public let id: Mountain.ID
  public var name: String
  public var displayDescription: String
  public var elevationMeters: Double
  public var latitude: Double
  public var longitude: Double
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
    self.dateAdded = dateAdded
    self.imageURL = imageURL
    self.difficulty = difficulty
  }
}

// MARK: - CachedUser

@Table("CachedUsers")
public struct CachedUserRecord: Hashable, Sendable {
  public let id: User.ID

  @Column(as: PersonNameComponents.JSONRepresentation.self)
  public var name: PersonNameComponents

  public var subtitle: String

  public init(user: User) {
    self.id = user.id
    self.name = user.name
    self.subtitle = user.subtitle
  }
}

extension User {
  public init(cached: CachedUserRecord) {
    self.init(id: cached.id, name: cached.name, subtitle: cached.subtitle)
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

// MARK: - MountainClimbGoalRecord

@Table("MountainClimbGoals")
public struct MountainClimbGoalRecord {
  public let id: UUID

  @Column(as: Mountain.IDRepresentation.self)
  public let mountainId: Mountain.ID

  public let dateAdded: Date
  public var achievedDate: Date?

  public init(id: UUID, mountainId: Mountain.ID, dateAdded: Date, achievedDate: Date?) {
    self.id = id
    self.mountainId = mountainId
    self.dateAdded = dateAdded
    self.achievedDate = achievedDate
  }
}

// MARK: - QueryAnalysisRecord

@Table("QueryAnalysis")
public struct QueryAnalysisRecord {
  public let id: QueryAnalysis.ID

  @Column(as: ApplicationLaunchID.Representation.self)
  public let launchId: ApplicationLaunchID

  public var queryRetryAttempt: Int
  public var queryRuntimeDuration: TimeInterval
  public var queryTypeName: String

  @Column(as: QueryAnalysis.DataResult.JSONRepresentation.self)
  public var queryDataResult: QueryAnalysis.DataResult

  public init(
    id: QueryAnalysis.ID,
    launchId: ApplicationLaunchID,
    queryRetryAttempt: Int,
    queryRuntimeDuration: TimeInterval,
    queryTypeName: String,
    queryDataResult: QueryAnalysis.DataResult
  ) {
    self.id = id
    self.launchId = launchId
    self.queryRetryAttempt = queryRetryAttempt
    self.queryRuntimeDuration = queryRuntimeDuration
    self.queryTypeName = queryTypeName
    self.queryDataResult = queryDataResult
  }
}

// MARK: - Can I Climb Database

public func canIClimbDatabase(url: URL? = nil) throws -> any DatabaseWriter {
  var configuration = Configuration()
  configuration.foreignKeysEnabled = isTesting

  let writer = try writer(for: url, configuration: configuration)
  var migrator = DatabaseMigrator()
  migrator.registerV1()
  try migrator.migrate(writer)
  return writer
}

private func writer(for url: URL?, configuration: Configuration) throws -> any DatabaseWriter {
  if let url {
    try DatabasePool(path: url.path, configuration: configuration)
  } else {
    try DatabaseQueue(configuration: configuration)
  }
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
          difficulty INTEGER NOT NULL,
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
        CREATE TABLE IF NOT EXISTS MountainClimbGoals (
          id BLOB PRIMARY KEY,
          mountainId BLOB NOT NULL,
          dateAdded TIMESTAMP NOT NULL,
          achievedDate TIMESTAMP,
          FOREIGN KEY (mountainId) REFERENCES CachedMountains(id)
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
  }
}

private let singleRowTablePrimaryKeyColumnSQL = "id BLOB PRIMARY KEY CHECK (id = '\(UUID.nil)')"
