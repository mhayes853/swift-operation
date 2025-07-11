import Dependencies
import Foundation

extension DependencyValues {
  public var notificationCenter: NotificationCenter {
    get { self[NotificationCenterKey.self] }
    set { self[NotificationCenterKey.self] = newValue }
  }

  private enum NotificationCenterKey: DependencyKey {
    static let liveValue = NotificationCenter.default
    static var testValue: NotificationCenter {
      NotificationCenter()
    }
  }
}
