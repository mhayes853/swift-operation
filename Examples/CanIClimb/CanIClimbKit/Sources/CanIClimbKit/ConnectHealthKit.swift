import Observation
import SharingGRDB
import SharingQuery
import SwiftUI
import SwiftUINavigation

@MainActor
@Observable
public final class ConnectToHealthKitModel {
  @ObservationIgnored
  @SingleRow(LocalInternalMetricsRecord.self) private var _localMetrics

  @ObservationIgnored
  @SharedQuery(HealthPermissions.requestMutation) private var request: Void?

  public init() {}

  public var isConnected: Bool {
    self._localMetrics.hasConnectedHealthKit
  }

  public func connectInvoked() async {
    try? await self.$request.mutate()
  }
}
