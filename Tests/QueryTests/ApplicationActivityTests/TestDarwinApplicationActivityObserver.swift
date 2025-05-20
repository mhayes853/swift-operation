import Foundation
import Query

@MainActor
struct TestDarwinApplicationActivityObserver: DarwinApplicationActivityObserver {
  static let didBecomeActiveNotification = Notification.Name.fakeDidBecomeActive
  static let willResignActiveNotification = Notification.Name.fakeWillResignActive

  let isInitiallyActive: Bool
  let notificationCenter: NotificationCenter
}

extension Notification.Name {
  static let fakeDidBecomeActive = Notification.Name("FakeDidBecomeActiveNotification")
  static let fakeWillResignActive = Notification.Name("FakeWillResignActiveNotification")
}
