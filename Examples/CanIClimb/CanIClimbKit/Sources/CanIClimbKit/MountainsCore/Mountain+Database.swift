import Foundation
import GRDB
import StructuredQueriesGRDB

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

  public static func findAll(matching name: String, in db: Database) throws -> [Self] {
    try CachedMountainRecord.all
      .where { name.eq("").or(#sql("localizedStandardContains(\($0.name), \(bind: name))")) }
      .order { $0.dateAdded.desc() }
      .fetchAll(db)
      .map(Mountain.init(cached:))
  }
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
    self.id = mountain.id
    self.name = mountain.name
    self.displayDescription = mountain.displayDescription
    self.elevationMeters = mountain.elevation.converted(to: .meters).value
    self.latitude = mountain.location.latitude
    self.longitude = mountain.location.longitude
    self.dateAdded = mountain.dateAdded
    self.imageURL = mountain.imageURL
    self.difficulty = mountain.difficulty
  }
}
