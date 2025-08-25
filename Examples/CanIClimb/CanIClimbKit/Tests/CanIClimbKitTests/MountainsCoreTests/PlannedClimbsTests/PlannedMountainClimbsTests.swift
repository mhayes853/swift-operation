import CanIClimbKit
import CustomDump
import Foundation
import GRDB
import Operation
import Testing

@Suite("PlannedMountainClimbs tests")
struct PlannedMountainClimbsTests {
  private let database = try! canIClimbDatabase()

  @Test("Plans Climb With Alarm, Returns Planned Climb With Alarm")
  func plansClimbWithAlarmReturnsPlannedClimbWithAlarm() async throws {
    var create = Mountain.ClimbPlanCreate.mock1
    create.alarm = Mountain.ClimbPlanCreate.Alarm(name: "Test", date: .distantFuture)
    let plannedClimbs = PlannedMountainClimbs(
      database: self.database,
      api: self.api(
        transport: .mock { [create] request, _ in
          if request == .planClimb(CanIClimbAPI.PlanClimbRequest(create: create)) {
            return (200, .json(CanIClimbAPI.PlannedClimbResponse(plannedClimb: .mock1)))
          }
          return (400, .data(Data()))
        }
      )
    )

    let climb = try await plannedClimbs.plan(create: create)
    let alarm = try #require(climb.alarm)

    expectNoDifference(alarm.date, .distantFuture)
    expectNoDifference(String(localized: alarm.title), "Test")
  }

  @Test("Plans Climb, Caches Planned Climb")
  func plansClimbCachesPlannedClimb() async throws {
    var create = Mountain.ClimbPlanCreate.mock1
    create.alarm = Mountain.ClimbPlanCreate.Alarm(mountainName: "Test", date: .distantFuture)
    let plannedClimbs = PlannedMountainClimbs(
      database: self.database,
      api: self.api(
        transport: .mock { [create] request, _ in
          if request == .planClimb(CanIClimbAPI.PlanClimbRequest(create: create)) {
            return (200, .json(CanIClimbAPI.PlannedClimbResponse(plannedClimb: .mock1)))
          }
          return (400, .data(Data()))
        }
      )
    )

    let climb = try await plannedClimbs.plan(create: create)
    let localClimbs = try await plannedClimbs.localPlannedClimbs(for: create.mountainId)

    expectNoDifference(localClimbs, [climb])
  }

  @Test("Caches Remotely Loaded Planned Climbs")
  func cachesRemotelyLoadedPlannedClimbs() async throws {
    let plannedClimbs = PlannedMountainClimbs(
      database: self.database,
      api: self.api(
        transport: .mock { request, _ in
          switch request {
          case .plannedClimbs:
            (200, .json([CanIClimbAPI.PlannedClimbResponse(plannedClimb: .mock1)]))
          default:
            (400, .data(Data()))
          }
        }
      )
    )

    let climbs = try await plannedClimbs.plannedClimbs(for: Mountain.mock1.id)
    let localClimbs = try await plannedClimbs.localPlannedClimbs(for: Mountain.mock1.id)

    expectNoDifference(localClimbs, climbs)
    expectNoDifference(climbs, [.mock1])
  }

  @Test("Keeps Alarm Info For Remotely Loaded Climbs")
  func keepsAlarmInfoForRemotelyLoadedPlannedClimbs() async throws {
    let plannedClimbs = PlannedMountainClimbs(
      database: self.database,
      api: self.api(
        transport: .mock { request, _ in
          switch request {
          case .planClimb:
            (201, .json(CanIClimbAPI.PlannedClimbResponse(plannedClimb: .mock1)))
          case .plannedClimbs:
            (200, .json([CanIClimbAPI.PlannedClimbResponse(plannedClimb: .mock1)]))
          default:
            (400, .data(Data()))
          }
        }
      )
    )

    var create = Mountain.ClimbPlanCreate.mock1
    create.alarm = Mountain.ClimbPlanCreate.Alarm(
      mountainName: Mountain.mock1.name,
      date: .distantFuture
    )
    let plannedClimb = try await plannedClimbs.plan(create: create)
    let climbs = try await plannedClimbs.plannedClimbs(for: Mountain.mock1.id)

    expectNoDifference(climbs.map(\.alarm), [plannedClimb.alarm])
  }

  @Test("Removes Locally Cached Planned Climb When Not In List")
  func removesLocallyCachedPlannedClimbWhenNotInList() async throws {
    let plannedClimbs = PlannedMountainClimbs(
      database: self.database,
      api: self.api(
        transport: .mock { request, _ in
          switch request {
          case .planClimb:
            (200, .json(CanIClimbAPI.PlannedClimbResponse(plannedClimb: .mock1)))
          case .plannedClimbs:
            (200, .json([CanIClimbAPI.PlannedClimbResponse]()))
          default:
            (400, .data(Data()))
          }
        }
      )
    )

    _ = try await plannedClimbs.plan(create: .mock1)
    _ = try await plannedClimbs.plannedClimbs(for: Mountain.mock1.id)
    let localClimbs = try await plannedClimbs.localPlannedClimbs(for: Mountain.mock1.id)

    expectNoDifference(localClimbs, [])
  }

  @Test("Removes Locally Cached Planned Climb When Unplanned")
  func removesLocallyCachedPlannedClimbWhenUnplanned() async throws {
    let plannedClimbs = PlannedMountainClimbs(
      database: self.database,
      api: self.api(
        transport: .mock { request, _ in
          switch request {
          case .planClimb:
            (200, .json(CanIClimbAPI.PlannedClimbResponse(plannedClimb: .mock1)))
          case .unplanClimbs([Mountain.PlannedClimb.mock1.id]):
            (204, .data(Data()))
          default:
            (400, .data(Data()))
          }
        }
      )
    )

    let climb = try await plannedClimbs.plan(create: .mock1)
    try await plannedClimbs.unplanClimbs(ids: [climb.id])
    let localClimbs = try await plannedClimbs.localPlannedClimbs(for: Mountain.mock1.id)

    expectNoDifference(localClimbs, [])
  }

  @Test("Updates Locally Cached Climb When Achieved")
  func updatesLocallyCachedClimbWhenAchieved() async throws {
    var achievedClimbResponse = CanIClimbAPI.PlannedClimbResponse(plannedClimb: .mock1)
    achievedClimbResponse.achievedDate = Date(
      timeIntervalSince1970: TimeInterval(Int(Date.now.timeIntervalSince1970))
    )

    let plannedClimbs = PlannedMountainClimbs(
      database: self.database,
      api: self.api(
        transport: .mock { [achievedClimbResponse] request, _ in
          switch request {
          case .planClimb:
            (200, .json(CanIClimbAPI.PlannedClimbResponse(plannedClimb: .mock1)))
          case .achieveClimb(Mountain.PlannedClimb.mock1.id):
            (200, .json(achievedClimbResponse))
          default:
            (400, .data(Data()))
          }
        }
      )
    )

    let climb = try await plannedClimbs.plan(create: .mock1)
    try await plannedClimbs.achieveClimb(id: climb.id)
    let localClimbs = try await plannedClimbs.localPlannedClimbs(for: Mountain.mock1.id)

    let expectedClimb = Mountain.PlannedClimb(cached: achievedClimbResponse, alarm: nil)
    expectNoDifference(localClimbs, [expectedClimb])
  }

  @Test("Updates Locally Cached Climb When Unachieved")
  func updatesLocallyCachedClimbWhenUnachieved() async throws {
    var achievedClimbResponse = CanIClimbAPI.PlannedClimbResponse(plannedClimb: .mock1)
    achievedClimbResponse.achievedDate = Date(
      timeIntervalSince1970: TimeInterval(Int(Date.now.timeIntervalSince1970))
    )

    let plannedClimbs = PlannedMountainClimbs(
      database: self.database,
      api: self.api(
        transport: .mock { [achievedClimbResponse] request, _ in
          switch request {
          case .plannedClimbs:
            (200, .json([achievedClimbResponse]))
          case .unachieveClimb(Mountain.PlannedClimb.mock1.id):
            (200, .json(CanIClimbAPI.PlannedClimbResponse(plannedClimb: .mock1)))
          default:
            (400, .data(Data()))
          }
        }
      )
    )

    _ = try await plannedClimbs.plannedClimbs(for: Mountain.mock1.id)
    try await plannedClimbs.unachieveClimb(id: achievedClimbResponse.id)
    let localClimbs = try await plannedClimbs.localPlannedClimbs(for: Mountain.mock1.id)

    expectNoDifference(localClimbs, [.mock1])
  }

  private func api(
    transport: any CanIClimbAPI.DataTransport
  ) -> CanIClimbAPI {
    CanIClimbAPI(
      transport: transport,
      tokens: CanIClimbAPI.Tokens(client: OperationClient(), secureStorage: InMemorySecureStorage())
    )
  }
}
