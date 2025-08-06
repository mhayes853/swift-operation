import Foundation
import GRDB
import StructuredQueriesGRDB
import Tagged
import UUIDV7

// MARK: - QueryBindable

extension Mountain.ClimbingDifficulty: QueryBindable {}

// MARK: - IDRepresentation

extension Mountain {
  public typealias IDRepresentation = Tagged<Self, UUIDV7.BytesRepresentation>
}

extension Mountain.PlannedClimb {
  public typealias IDRepresentation = Tagged<Self, UUIDV7.BytesRepresentation>
}

// MARK: - Conversions

extension Mountain {
  public init(cached record: CachedMountainRecord) {
    self.init(
      id: record.id,
      name: record.name,
      displayDescription: record.displayDescription,
      elevation: Measurement(value: record.elevationMeters, unit: .meters),
      coordinate: LocationCoordinate2D(latitude: record.latitude, longitude: record.longitude),
      locationName: record.locationName,
      dateAdded: record.dateAdded,
      difficulty: record.difficulty,
      imageURL: record.imageURL
    )
  }
}

extension CachedMountainRecord {
  public init(mountain: Mountain) {
    self.init(
      id: mountain.id,
      name: mountain.name,
      displayDescription: mountain.displayDescription,
      elevationMeters: mountain.elevation.converted(to: .meters).value,
      latitude: mountain.coordinate.latitude,
      longitude: mountain.coordinate.longitude,
      locationName: mountain.locationName,
      dateAdded: mountain.dateAdded,
      imageURL: mountain.imageURL,
      difficulty: mountain.difficulty
    )
  }
}

// MARK: - PlannedClimb Conversions

extension Mountain.PlannedClimb {
  public init(cached record: CachedPlannedClimbRecord, alarm: ScheduleableAlarm?) {
    self.init(
      id: record.id,
      mountainId: record.mountainId,
      targetDate: record.targetDate,
      achievedDate: record.achievedDate,
      alarm: alarm
    )
  }
}

extension CachedPlannedClimbRecord {
  public init(plannedClimb: Mountain.PlannedClimb) {
    self.init(
      id: plannedClimb.id,
      mountainId: plannedClimb.mountainId,
      targetDate: plannedClimb.targetDate,
      achievedDate: plannedClimb.achievedDate
    )
  }
}
