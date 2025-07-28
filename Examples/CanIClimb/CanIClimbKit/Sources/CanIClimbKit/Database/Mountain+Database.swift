import Foundation
import GRDB
import StructuredQueriesGRDB
import Tagged
import UUIDV7

// MARK: - Saving

extension Mountain {
  public static func save(_ mountains: some Sequence<Self>, in db: Database) throws {
    let cachedMountains = mountains.map {
      CachedMountainRecord.Draft(CachedMountainRecord(mountain: $0))
    }
    try CachedMountainRecord.upsert { cachedMountains }
      .execute(db)
  }
}

// MARK: - Deleting

extension Mountain {
  public static func delete(by id: ID, in db: Database) throws {
    try CachedMountainRecord.delete()
      .where { $0.id.eq(#bind(id)) }
      .execute(db)
  }
}

// MARK: - Loading

extension Mountain {
  public static func find(by id: ID, in db: Database) throws -> Self? {
    try CachedMountainRecord.find(#bind(id))
      .fetchOne(db)
      .map(Mountain.init(cached:))
  }

  public static func findAll(matching search: Search, in db: Database) throws -> [Self] {
    try CachedMountainRecord.all
      .leftJoin(CachedPlannedClimbRecord.all) { $0.id.eq($1.mountainId) }
      .where {
        let doesMatch = search.text.eq("")
          .or(#sql("localizedStandardContains(\($0.name), \(bind: search.text))"))
        switch search.category {
        case .recommended:
          doesMatch
        case .planned:
          doesMatch.and($1.id.isNot(nil))
        }
      }
      .order { (m, _) in m.dateAdded.desc() }
      .select { (m, _) in m }
      .fetchAll(db)
      .map(Mountain.init(cached:))
  }
}

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
      location: LocationCoordinate2D(latitude: record.latitude, longitude: record.longitude),
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
      latitude: mountain.location.latitude,
      longitude: mountain.location.longitude,
      dateAdded: mountain.dateAdded,
      imageURL: mountain.imageURL,
      difficulty: mountain.difficulty
    )
  }
}
