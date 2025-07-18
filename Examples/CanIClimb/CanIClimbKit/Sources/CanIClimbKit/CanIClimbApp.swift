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

  @ObservationIgnored
  @Dependency(\.defaultDatabase) private var database

  public var destination: Destination? {
    didSet { self.bind() }
  }

  public init() {}
}

extension CanIClimbModel {
  public func appeared() async throws {
    let hasFinishedOnboarding = try await self.database.read {
      InternalMetricsRecord.find(in: $0).hasCompletedOnboarding
    }
    if !hasFinishedOnboarding {
      self.destination = .onboarding(OnboardingModel())
    }
  }
}

extension CanIClimbModel {
  public func settingsInvoked() {
    self.destination = .settings(SettingsModel())
  }
}

extension CanIClimbModel {
  @CasePathable
  public enum Destination: Hashable, Sendable {
    case onboarding(OnboardingModel)
    case settings(SettingsModel)
  }

  private func bind() {
    switch self.destination {
    case .onboarding(let model):
      model.onFinished = { [weak self] in self?.destination = nil }
    default:
      break
    }
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
  @Bindable var model: CanIClimbModel

  public var body: some View {
    Text("TODO")
      .observeQueryAlerts()
      .task { try? await self.model.appeared() }
      #if os(iOS)
        .shakeDetection()
        .fullScreenCover(item: self.$model.destination.onboarding) { model in
          OnboardingView(model: model)
        }
      #else
        .sheet(item: self.$model.destination.onboarding) { model in
          OnboardingView(model: model)
        }
      #endif
  }
}
