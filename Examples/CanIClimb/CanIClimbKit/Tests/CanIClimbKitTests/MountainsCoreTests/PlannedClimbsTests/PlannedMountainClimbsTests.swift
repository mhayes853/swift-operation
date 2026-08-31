import CanIClimbKit
import CustomDump
import Dependencies
import Foundation
import GRDB
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
      api: self.api()
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
      api: self.api()
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
        scenario: DummyBackend.Scenario(
          plannedClimbs: [CanIClimbAPI.PlannedClimbResponse(plannedClimb: .mock1)]
        )
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
      api: self.api()
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
        responseOverride: { request in
          guard request.httpMethod == "GET", request.url?.path().hasSuffix("/climbs") == true
          else { return nil }
          return DummyBackend.Response.json([CanIClimbAPI.PlannedClimbResponse]())
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
      api: self.api()
    )

    let climb = try await plannedClimbs.plan(create: .mock1)
    try await plannedClimbs.unplanClimbs(ids: [climb.id])
    let localClimbs = try await plannedClimbs.localPlannedClimbs(for: Mountain.mock1.id)

    expectNoDifference(localClimbs, [])
  }

  @Test("Updates Locally Cached Climb When Achieved")
  func updatesLocallyCachedClimbWhenAchieved() async throws {
    let now = Date(timeIntervalSince1970: 1_234_567_890)
    let plannedClimbs = PlannedMountainClimbs(
      database: self.database,
      api: self.api()
    )

    try await withDependencies {
      $0.date.now = now
    } operation: {
      var expectedClimb = try await plannedClimbs.plan(create: .mock1)
      try await plannedClimbs.achieveClimb(id: expectedClimb.id)
      let localClimbs = try await plannedClimbs.localPlannedClimbs(for: Mountain.mock1.id)

      expectedClimb.achievedDate = now
      expectNoDifference(localClimbs, [expectedClimb])
    }
  }

  @Test("Updates Locally Cached Climb When Unachieved")
  func updatesLocallyCachedClimbWhenUnachieved() async throws {
    var achievedClimbResponse = CanIClimbAPI.PlannedClimbResponse(plannedClimb: .mock1)
    achievedClimbResponse.achievedDate = Date(timeIntervalSince1970: 1_234_567_890)

    let plannedClimbs = PlannedMountainClimbs(
      database: self.database,
      api: self.api(
        scenario: DummyBackend.Scenario(plannedClimbs: [achievedClimbResponse])
      )
    )

    _ = try await plannedClimbs.plannedClimbs(for: Mountain.mock1.id)
    try await plannedClimbs.unachieveClimb(id: achievedClimbResponse.id)
    let localClimbs = try await plannedClimbs.localPlannedClimbs(for: Mountain.mock1.id)

    expectNoDifference(localClimbs, [.mock1])
  }

  private func api(
    scenario: DummyBackend.Scenario = DummyBackend.Scenario(),
    responseOverride: @escaping DummyBackend.ResponseOverride = { _ in nil }
  ) -> CanIClimbAPI {
    CanIClimbAPI.testInstance(
      transport: DummyBackend(scenario: scenario, responseOverride: responseOverride),
      isAuthenticated: true
    )
  }
}
