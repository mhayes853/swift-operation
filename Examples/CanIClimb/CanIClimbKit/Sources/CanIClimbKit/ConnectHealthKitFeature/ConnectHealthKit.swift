import Observation
import SharingGRDB
import SwiftUI
import SwiftUINavigation

// MARK: - ConnectToHealthKitModel

@MainActor
@Observable
public final class ConnectToHealthKitModel {
  @ObservationIgnored
  @Fetch(wrappedValue: LocalInternalMetricsRecord(), .singleRow(LocalInternalMetricsRecord.self))
  private var _localMetrics

  @ObservationIgnored
  @Dependency(HealthPermissions.self) private var healthPermissions

  public var destination: Destination?

  public init() {}
}

extension ConnectToHealthKitModel {
  @CasePathable
  public enum Destination: Hashable, Sendable {
    case alert(AlertState<ConnectToHealthKitModel.AlertAction>)
  }
}

extension ConnectToHealthKitModel {
  public var isConnected: Bool {
    self._localMetrics.hasConnectedHealthKit
  }

  public func connectInvoked() async {
    do {
      try await self.healthPermissions.request()
      self.destination = .alert(.successfullyConnectedToHealthKit)
    } catch {
      self.destination = .alert(.failedToConnectToHealthKit)
    }
  }
}

// MARK: - AlertState

extension ConnectToHealthKitModel {
  public enum AlertAction: Hashable, Sendable {}
}

extension AlertState where Action == ConnectToHealthKitModel.AlertAction {
  public static let failedToConnectToHealthKit = Self {
    TextState("Failed to Connect to HealthKit")
  } message: {
    TextState("Please try again later.")
  }

  public static let successfullyConnectedToHealthKit = Self {
    TextState("Successfully Connected to HealthKit")
  } message: {
    TextState("Enjoy your climbing journey!")
  }
}

// MARK: - ViewModifier

extension View {
  public func connectToHealthKit(model: ConnectToHealthKitModel) -> some View {
    self.modifier(ConnectToHealthKitModifier(model: model))
  }
}

private struct ConnectToHealthKitModifier: ViewModifier {
  @Bindable var model: ConnectToHealthKitModel

  public func body(content: Content) -> some View {
    content
      .alert(self.$model.destination.alert) { _ in }
  }
}
