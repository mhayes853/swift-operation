import Foundation
@_spi(ApplicationActivityObserver) import Query

@MainActor
struct TestApplicationActivityObserver: ApplicationActivityObserver {
  static let didBecomeActiveNotification = Notification.Name.fakeDidBecomeActive
  static let willResignActiveNotification = Notification.Name.fakeWillResignActive

  let isInitiallyActive: Bool
}

extension Notification.Name {
  static let fakeDidBecomeActive = Notification.Name("FakeDidBecomeActiveNotification")
  static let fakeWillResignActive = Notification.Name("FakeWillResignActiveNotification")
}
