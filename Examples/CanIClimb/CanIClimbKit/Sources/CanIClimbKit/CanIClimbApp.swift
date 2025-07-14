import Dependencies
import Observation
import SharingGRDB
import SwiftUI
import SwiftUINavigation

// MARK: - CanIClimbModel

@MainActor
@Observable
public final class CanIClimbModel {
  private let analyzer = QueryAnalyzerModel()

  public var destination: Destination?

  public init() {}
}

extension CanIClimbModel {
  @CasePathable
  public enum Destination: Hashable, Sendable {
    case onboarding(OnboardingModel)
    case queryAnalyzer(QueryAnalyzerModel)
    case settings(SettingsModel)
  }
}

// MARK: - CanIClimbApp

public struct CanIClimbApp: App {
  private let model: CanIClimbModel

  public init() {
    try! prepareDependencies {
      $0.defaultDatabase = try canIClimbDatabase(
        url: .applicationSupportDirectory.appending(path: "db/can-i-climb.db")
      )
      $0.defaultSyncEngine = try .canIClimb(writer: $0.defaultDatabase)
      $0[UserLocationKey.self] = CLUserLocation()
    }
    self.model = CanIClimbModel()
  }

  public var body: some Scene {
    WindowGroup {
      CanIClimbView(model: self.model)
    }
  }
}

// MARK: - CanIClimbView

public struct CanIClimbView: View {
  let model: CanIClimbModel

  public var body: some View {
    Text("TODO")
      .observeQueryAlerts()
  }
}
