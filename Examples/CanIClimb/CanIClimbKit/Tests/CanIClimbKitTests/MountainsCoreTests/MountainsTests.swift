import CanIClimbKit
import CustomDump
import Foundation
import IdentifiedCollections
import Synchronization
import Testing

@Suite("Mountains tests")
struct MountainsTests {
  private let database = try! canIClimbDatabase()

  @Test("Caches Mountain After Fetching")
  func cachesMountainAfterFetching() async throws {
    let api = CanIClimbAPI.testInstance(
      transport: .mock { request, _ in
        switch request {
        case .mountain(Mountain.mock1.id):
          (200, .json(Mountain.mock1))
        default:
          (404, .data(Data()))
        }
      }
    )

    let mountains = Mountains(database: self.database, api: api)
    let remoteMountain = try await mountains.mountain(with: Mountain.mock1.id)
    let localMountain = try await mountains.localMountain(with: Mountain.mock1.id)

    expectNoDifference(remoteMountain, localMountain)
    expectNoDifference(remoteMountain, .mock1)
  }

  @Test("Deletes Cached Mountain When Nil Returned")
  func deletesCachedMountainWhenNilReturned() async throws {
    let mountainFetchCount = Mutex(0)
    let api = CanIClimbAPI.testInstance(
      transport: .mock { request, _ in
        switch request {
        case .mountain(Mountain.mock1.id):
          return mountainFetchCount.withLock { count in
            defer { count += 1 }
            if count == 0 {
              return (200, .json(Mountain.mock1))
            } else {
              return (404, .data(Data()))
            }
          }
        default:
          return (400, .data(Data()))
        }
      }
    )

    let mountains = Mountains(database: self.database, api: api)
    _ = try await mountains.mountain(with: Mountain.mock1.id)
    _ = try await mountains.mountain(with: Mountain.mock1.id)
    let localMountain = try await mountains.localMountain(with: Mountain.mock1.id)

    expectNoDifference(localMountain, nil)
  }

  @Test("Caches Individual Mountains From Search")
  func cachesIndividualMountainsFromSearch() async throws {
    let api = CanIClimbAPI.testInstance(
      transport: .mock { request, _ in
        switch request {
        case .searchMountains:
          (200, .json(Mountain.SearchResult(mountains: [.mock1], hasNextPage: false)))
        default:
          (404, .data(Data()))
        }
      }
    )

    let mountains = Mountains(database: self.database, api: api)
    let remoteMountains = try await mountains.searchMountains(by: .recommended(page: 0))
    let localMountains = try await mountains.localSearchMountains(by: Mountain.Search(text: ""))

    expectNoDifference(remoteMountains.mountains, localMountains)
    expectNoDifference(remoteMountains.mountains, [.mock1])
  }

  @Test(
    "Local Searches Mountains By Text",
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
  func localSearchMountains(by search: Mountain.Search, searchMocksIndicies: [Int]) async throws {
    let api = CanIClimbAPI.testInstance(
      transport: .mock { request, _ in
        switch request {
        case .planClimb:
          (201, .json(CanIClimbAPI.PlannedClimbResponse.searchMocks[0]))
        case .searchMountains:
          (200, .json(Mountain.SearchResult(mountains: Mountain.searchMocks, hasNextPage: false)))
        default:
          (404, .data(Data()))
        }
      }
    )

    let mountains = Mountains(database: self.database, api: api)
    let plannedClimbs = PlannedMountainClimbs(database: self.database, api: api)

    _ = try await plannedClimbs.plan(create: .mock1)
    _ = try await mountains.searchMountains(by: .recommended(page: 0))

    let localMountains = try await mountains.localSearchMountains(by: search)
    let expected = searchMocksIndicies.map { Mountain.searchMocks[$0] }
    expectNoDifference(Array(localMountains), expected)
  }

  @Test("Only Local Searches 1 Copy Of Mountain With Multiple Planned Climbs")
  func onlyLocalSearches1CopyOfMountainWithMultiplePlannedClimbs() async throws {
    var planned1 = Mountain.PlannedClimb.mock1
    var planned2 = Mountain.PlannedClimb(
      cached: CachedPlannedClimbRecord.searchMocks[0],
      alarm: nil
    )
    planned2.mountainId = Mountain.searchMocks[1].id
    planned1.mountainId = planned2.mountainId

    let api = CanIClimbAPI.testInstance(
      transport: .mock { [planned1, planned2] request, _ in
        switch request {
        case .plannedClimbs:
          (
            200,
            .json([
              CanIClimbAPI.PlannedClimbResponse(plannedClimb: planned1),
              CanIClimbAPI.PlannedClimbResponse(plannedClimb: planned2)
            ])
          )
        case .searchMountains:
          (200, .json(Mountain.SearchResult(mountains: Mountain.searchMocks, hasNextPage: false)))
        default:
          (404, .data(Data()))
        }
      }
    )

    let mountains = Mountains(database: self.database, api: api)
    let plannedClimbs = PlannedMountainClimbs(database: self.database, api: api)

    _ = try await plannedClimbs.plannedClimbs(for: planned1.mountainId)
    _ = try await mountains.searchMountains(by: .recommended(page: 0))

    let localMountains = try await mountains.localSearchMountains(by: .planned)
    expectNoDifference(localMountains, [Mountain.searchMocks[1]])
  }
}

extension Mountain {
  fileprivate static let searchMocks: IdentifiedArrayOf<Self> = {
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
  fileprivate static let searchMocks = [
    Self(
      id: ID(),
      mountainId: Mountain.searchMocks[1].id,
      targetDate: .distantFuture,
      achievedDate: nil
    )
  ]
}
