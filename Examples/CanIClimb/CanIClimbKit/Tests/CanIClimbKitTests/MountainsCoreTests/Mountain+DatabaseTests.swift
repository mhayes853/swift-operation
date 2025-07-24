import CanIClimbKit
import CustomDump
import GRDB
import Testing

@Suite("Mountain+Database tests")
struct MountainDatabaseTests {
  private let database = try! canIClimbDatabase()

  @Test("Searches Mountains By Text")
  func searchesMountainsByText() async throws {
    var m1 = Mountain.mock1
    m1.name = "Mount Whitney"

    var m2 = Mountain.mock1
    m2.id = Mountain.ID()
    m2.name = "Mount Everest"

    var m3 = Mountain.mock1
    m3.id = Mountain.ID()
    m3.name = "K2"

    let (r1, r2, r3, r4) = try await self.database.write { [m1, m2, m3] db in
      try Mountain.save([m1, m2, m3], in: db)
      let r1 = try Mountain.findAll(matching: "mount", in: db)
      let r2 = try Mountain.findAll(matching: "k", in: db)
      let r3 = try Mountain.findAll(matching: "WHIT", in: db)
      let r4 = try Mountain.findAll(matching: "", in: db)
      return (r1, r2, r3, r4)
    }

    expectNoDifference(r1, [m1, m2])
    expectNoDifference(r2, [m3])
    expectNoDifference(r3, [m1])
    expectNoDifference(r4, [m1, m2, m3])
  }
}
