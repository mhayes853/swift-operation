import Dependencies
import SharingGRDB
import SwiftUI

public struct CanIClimbApp: App {
  public init() {
    try! prepareDependencies {
      $0.defaultDatabase = try canIClimbDatabase(
        url: .applicationSupportDirectory.appending(path: "db/can-i-climb.db")
      )
      $0.defaultSyncEngine = try .canIClimb(writer: $0.defaultDatabase)
      $0[UserLocationKey.self] = CLUserLocation()
    }
  }

  public var body: some Scene {
    WindowGroup {
      Text("TODO")
        .observeQueryAlerts()
    }
  }
}
