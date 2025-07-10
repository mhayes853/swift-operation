import Observation
import SwiftUI

// MARK: - UserSettingsModel

@MainActor
@Observable
public final class UserSettingsModel {
  public var name: String
  public var subtitle: String

  @ObservationIgnored public var onSignOut: (() -> Void)?

  public init(user: User) {
    self.name = user.name.formatted()
    self.subtitle = user.subtitle
  }
}
