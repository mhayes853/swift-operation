import Foundation
import Query

// MARK: - TestApplicationActivityObserver

final class TestApplicationActivityObserver: ApplicationActivityObserver {
  private typealias Handler = @Sendable (Bool) -> Void

  private let subscriptions = QuerySubscriptions<Handler>()
  private let isActive = Lock(false)

  func subscribe(_ handler: @escaping @Sendable (Bool) -> Void) -> QuerySubscription {
    self.isActive.withLock {
      handler($0)
      return self.subscriptions.add(handler: handler).subscription
    }
  }

  func send(isActive: Bool) {
    self.isActive.withLock {
      $0 = isActive
      self.subscriptions.forEach { handler in handler(isActive) }
    }
  }
}

// MARK: - TestDarwinApplicationActivityObserver

#if canImport(Darwin)
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
#endif
