import GRDB
import IdentifiedCollections
import StructuredQueriesGRDB

// MARK: - Mountains

public final class Mountains: Sendable {
  private let database: any DatabaseWriter
  private let api: CanIClimbAPI

  public init(database: any DatabaseWriter, api: CanIClimbAPI) {
    self.database = database
    self.api = api
  }
}

// MARK: - Searcher

extension Mountains: Mountain.Searcher {
  public func localSearchMountains(
    by search: Mountain.Search
  ) async throws -> IdentifiedArrayOf<Mountain> {
    let mountains = try await self.database.read { db in
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
    return IdentifiedArray(uniqueElements: mountains)
  }

  public func searchMountains(
    by request: Mountain.SearchRequest
  ) async throws -> Mountain.SearchResult {
    let searchResult = try await self.api.searchMountains(by: request)
    try await self.save(searchResult.mountains)
    return searchResult
  }
}

// MARK: - Loader

extension Mountains: Mountain.Loader {
  public func localMountain(with id: Mountain.ID) async throws -> Mountain? {
    try await self.database.read { db in
      try CachedMountainRecord.find(#bind(id))
        .fetchOne(db)
        .map(Mountain.init(cached:))
    }
  }

  public func mountain(with id: Mountain.ID) async throws -> Mountain? {
    guard let mountain = try await self.api.mountain(with: id) else {
      try await self.database.write { db in
        try CachedMountainRecord.find(#bind(id))
          .delete()
          .execute(db)
      }
      return nil
    }
    try await self.save(CollectionOfOne(mountain))
    return mountain
  }
}

// MARK: - Helpers

extension Mountains {
  private func save(_ mountains: some Sequence<Mountain> & Sendable) async throws {
    try await self.database.write { db in
      let cachedMountains = mountains.map {
        CachedMountainRecord.Draft(CachedMountainRecord(mountain: $0))
      }
      try CachedMountainRecord.upsert { cachedMountains }
        .execute(db)
    }
  }
}
