import CanIClimbKit
import CustomDump
import Foundation
import GRDB
import Query
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
          if request == .plannedClimbs(Mountain.mock1.id) {
            return (200, .json([CanIClimbAPI.PlannedClimbResponse(plannedClimb: .mock1)]))
          }
          return (400, .data(Data()))
        }
      )
    )

    let climbs = try await plannedClimbs.plannedClimbs(for: Mountain.mock1.id)
    let localClimbs = try await plannedClimbs.localPlannedClimbs(for: Mountain.mock1.id)

    expectNoDifference(localClimbs, climbs)
    expectNoDifference(climbs, [.mock1])
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
    let climbs = try await plannedClimbs.plannedClimbs(for: Mountain.mock1.id)
    let localClimbs = try await plannedClimbs.localPlannedClimbs(for: Mountain.mock1.id)

    expectNoDifference(localClimbs, climbs)
    expectNoDifference(climbs, [])
  }

  private func api(
    transport: any CanIClimbAPI.DataTransport
  ) -> CanIClimbAPI {
    CanIClimbAPI(
      transport: transport,
      tokens: CanIClimbAPI.Tokens(client: QueryClient(), secureStorage: InMemorySecureStorage())
    )
  }
}
