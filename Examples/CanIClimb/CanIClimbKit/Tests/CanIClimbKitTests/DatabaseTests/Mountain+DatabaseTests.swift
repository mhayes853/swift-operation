import CanIClimbKit
import CustomDump
import Foundation
import GRDB
import Testing

@Suite("Mountain+Database tests")
struct MountainDatabaseTests {
  private let database = try! canIClimbDatabase()

  @Test(
    "Searches Mountains By Text",
    arguments: [
      (Mountain.Search(text: ""), [0, 1, 2]),
      (Mountain.Search(text: "mount"), [0, 1]),
      (Mountain.Search(text: "k"), [2]),
      (Mountain.Search(text: "WHIT"), [0]),
      (Mountain.Search.recommended, [0, 1, 2]),
      (Mountain.Search.planned, [1]),
      (Mountain.Search(text: "blob", category: .planned), [])
    ]
  )
  func searchesMountainsByText(search: Mountain.Search, indicies: [Int]) async throws {
    let results = try await self.database.write { db in
      try Mountain.save(Mountain.searchMocks, in: db)
      try CachedPlannedClimbRecord.insert { CachedPlannedClimbRecord.mocks }
        .execute(db)
      return try Mountain.findAll(matching: search, in: db)
    }
    let expected = indicies.map { Mountain.searchMocks[$0] }
    expectNoDifference(results, expected)
  }
}

extension Mountain {
  fileprivate static let searchMocks: [Self] = {
    var m1 = Mountain.mock1
    m1.name = "Mount Whitney"

    var m2 = Mountain.mock1
    m2.id = Mountain.ID()
    m2.name = "Mount Everest"

    var m3 = Mountain.mock1
    m3.id = Mountain.ID()
    m3.name = "K2"
    return [m1, m2, m3]
  }()
}

extension CachedPlannedClimbRecord {
  fileprivate static let mocks = [
    Self(
      id: ID(),
      mountainId: Mountain.searchMocks[1].id,
      targetDate: .distantFuture,
      achievedDate: nil
    )
  ]
}
