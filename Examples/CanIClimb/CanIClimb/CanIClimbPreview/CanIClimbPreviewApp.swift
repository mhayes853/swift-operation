import CanIClimbKit
import CloudKit
import Dependencies
import IdentifiedCollections
import Operation
import SQLiteData
import SharingOperation
import SwiftUI
import Tagged
import UUIDV7

@main
struct CanIClimbPreviewApp: App {
  private let model: CanIClimbModel

  init() {
    try! prepareDependencies {
      $0.context = .preview
      $0.defaultOperationClient = OperationClient(storeCreator: .canIClimb)
      $0.defaultDatabase = try canIClimbDatabase()

      $0[UserLocationKey.self] = CLUserLocation()
      $0[DeviceInfo.self] = DeviceInfo.current

      let searcher = Mountain.MockSearcher()
      let plannedClimbs = Mountain.MockPlannedClimbsLoader()
      for i in 0..<10 {
        var mountains = IdentifiedArrayOf<Mountain>()
        for j in 0..<10 {
          var mountain = Mountain.freelPeak
          mountain.name = "Mountain \((i + 1) * (j + 1))"
          mountain.id = Mountain.ID()
          mountain.location = Mountain.Location(
            coordinate: .random(),
            name: mountain.location.name
          )
          mountains.append(mountain)

          guard j.isMultiple(of: 2) else { continue }

          var climbs = IdentifiedArrayOf<Mountain.PlannedClimb>()
          for k in 0..<10 {
            let alarm = ScheduleableAlarm(
              id: ScheduleableAlarm.ID(),
              title: "My Alarm",
              date: .now + 8000
            )
            let climb = Mountain.PlannedClimb(
              id: Mountain.PlannedClimb.ID(),
              mountainId: mountain.id,
              targetDate: .now + 10_000,
              achievedDate: k.isMultiple(of: 2) ? .now + 5000 : nil,
              alarm: k.isMultiple(of: 3) ? alarm : nil
            )
            climbs.append(climb)
          }
          plannedClimbs.results[mountain.id] = .success(climbs)
        }
        searcher.results[.recommended(page: i)] = .success(
          Mountain.SearchResult(mountains: mountains, hasNextPage: i < 9)
        )
      }
      $0[Mountain.SearcherKey.self] = searcher

      $0[CKAccountStatus.LoaderKey.self] = CKAccountStatus.MockLoader { .available }

      $0[User.CurrentLoaderKey.self] = User.MockCurrentLoader(result: .success(.user(.mock1)))

      $0[Mountain.PlanClimberKey.self] = Mountain.SucceedingClimbPlanner()
      $0[Mountain.PlannedClimbsLoaderKey.self] = plannedClimbs

      $0[WeatherReading.CurrentReaderKey.self] = WeatherReading.SucceedingCurrentReader()
      
      let location = MockUserLocation()
      location.currentReading = .success(.mock(coordinate: .alcatraz))
      $0[UserLocationKey.self] = location

      try $0.defaultDatabase.write {
        try InternalMetricsRecord.update(in: $0) { $0.hasCompletedOnboarding = true }
      }
    }
    self.model = CanIClimbModel()
  }

  var body: some Scene {
    WindowGroup {
      CanIClimbView(model: self.model)
    }
  }
}
