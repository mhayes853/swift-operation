import Dependencies
import FoundationModels
import Observation
import Operation
import SharingGRDB
import SwiftUI
import SwiftUINavigation

// MARK: - CanIClimbModel

@MainActor
@Observable
public final class CanIClimbModel {
  @ObservationIgnored
  @Dependency(\.defaultDatabase) private var database

  public var devTools: OperationDevToolsModel? {
    didSet { self.bind() }
  }

  public var destination: Destination? {
    didSet { self.bind() }
  }

  @ObservationIgnored
  @Dependency(\.notificationCenter) var center

  @ObservationIgnored
  @Dependency(ApplicationLaunch.ID.self) var launchId

  @ObservationIgnored
  @Dependency(DeviceInfo.self) var deviceInfo

  @ObservationIgnored
  @Dependency(ScheduleableAlarm.SyncEngine.self) var alarmSyncEngine

  private var token: NotificationCenter.ObservationToken?

  public let mountainsList = MountainsListModel()

  public init() {}
}

extension CanIClimbModel {
  public func appeared() async throws {
    try await self.alarmSyncEngine?.start()
    self.token = self.center.addObserver(for: DeviceShakeMessage.self) { [weak self] _ in
      self?.devTools = self?.devTools ?? OperationDevToolsModel()
    }
    let hasFinishedOnboarding = try await self.database.write { [launchId, deviceInfo] db in
      try ApplicationLaunchRecord.insert {
        ApplicationLaunchRecord(id: launchId, localizedDeviceName: deviceInfo.localizedModelName)
      }
      .execute(db)
      return InternalMetricsRecord.find(in: db).hasCompletedOnboarding
    }
    if !hasFinishedOnboarding {
      self.destination = .onboarding(OnboardingModel())
    }
  }

  public func disappeared() async {
    guard let token else { return }
    self.center.removeObserver(token)
    await self.alarmSyncEngine?.stop()
  }
}

extension CanIClimbModel {
  @CasePathable
  public enum Destination: Hashable, Sendable {
    case onboarding(OnboardingModel)
  }

  private func bind() {
    self.devTools?.onDismissed = { [weak self] in self?.devTools = nil }
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
      $0.defaultOperationClient = .canIClimb
      $0.defaultDatabase = try canIClimbDatabase(
        url: .applicationSupportDirectory.appending(path: "db/can-i-climb.db")
      )
      $0.defaultSyncEngine = try .canIClimb(writer: $0.defaultDatabase)
      $0[UserLocationKey.self] = CLUserLocation()
      $0[DeviceInfo.self] = DeviceInfo.current
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
  @Bindable private var model: CanIClimbModel
  private let systemLanguageModel = SystemLanguageModel.default

  public init(model: CanIClimbModel) {
    self.model = model
  }

  public var body: some View {
    Group {
      if let devToolsModel = self.model.devTools {
        OperationDevToolsView(model: devToolsModel)
          .transition(.opacity)
      } else {
        MountainsListView(model: self.model.mountainsList) { content in
          content
            #if os(iOS)
              .fullScreenCover(item: self.$model.destination.onboarding) { model in
                OnboardingView(model: model).background(.background)
              }
            #else
              .sheet(item: self.$model.destination.onboarding) { model in
                OnboardingView(model: model)
              }
            #endif
        }
        .transition(.opacity)
      }
    }
    .animation(.easeInOut, value: self.model.devTools)
    .observeOperationAlerts()
    .task {
      await withErrorReporting { try await self.model.appeared() }
    }
    .onDisappear { Task { await self.model.disappeared() } }
    .environment(\.systemLanguageModelAvailability, self.systemLanguageModel.availability)
  }
}
