import CanIClimbKit
import CloudKit
import Dependencies
import IdentifiedCollections
import Query
import SharingGRDB
import SharingQuery
import SwiftUI
import UUIDV7

@main
struct CanIClimbPreviewApp: App {
  private let model: CanIClimbModel

  init() {
    try! prepareDependencies {
      $0.context = .preview
      $0.defaultQueryClient = QueryClient(storeCreator: .canIClimb)
      $0.defaultDatabase = try canIClimbDatabase()

      $0[UserLocationKey.self] = CLUserLocation()
      $0[DeviceInfo.self] = DeviceInfo.current

      let searcher = Mountain.MockSearcher()
      for i in 0..<10 {
        var mountains = IdentifiedArrayOf<Mountain>()
        for j in 0..<10 {
          var mountain = Mountain.mock2
          mountain.name = "Mountain \((i + 1) * (j + 1))"
          mountain.id = Mountain.ID()
          mountain.coordinate = .random()
          mountains.append(mountain)
        }
        searcher.results[.recommended(page: i)] = .success(
          Mountain.SearchResult(mountains: mountains, hasNextPage: i < 9)
        )
      }
      $0[Mountain.SearcherKey.self] = searcher

      $0[CKAccountStatus.LoaderKey.self] = CKAccountStatus.MockLoader { .available }

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
