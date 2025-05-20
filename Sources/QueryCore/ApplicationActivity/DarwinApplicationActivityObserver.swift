#if canImport(Darwin)
  import Foundation

  #if canImport(AppKit)
    import AppKit
  #endif
  #if canImport(UIKit)
    import UIKit
  #endif
  #if canImport(WatchKit)
    import WatchKit
  #endif

  // MARK: - DarwinApplicationActivityObserver

  @MainActor
  package protocol DarwinApplicationActivityObserver: ApplicationActivityObserver {
    static var didBecomeActiveNotification: Notification.Name { get }
    static var willResignActiveNotification: Notification.Name { get }
    var notificationCenter: NotificationCenter { get }

    var isInitiallyActive: Bool { get }
  }

  extension DarwinApplicationActivityObserver {
    package var notificationCenter: NotificationCenter { .default }
  }

  extension DarwinApplicationActivityObserver {
    public nonisolated func subscribe(
      _ handler: @escaping @Sendable (Bool) -> Void
    ) -> QuerySubscription {
      let state = Lock<NotificationsState?>(nil)
      MainActor.runSyncIfAble {
        state.withLock { state in
          handler(self.isInitiallyActive)
          let didBecomeActiveObserver = self.notificationCenter.addObserver(
            forName: Self.didBecomeActiveNotification,
            object: nil,
            queue: nil
          ) { _ in handler(true) }
          let willResignActiveObserver = self.notificationCenter.addObserver(
            forName: Self.willResignActiveNotification,
            object: nil,
            queue: nil
          ) { _ in handler(false) }
          state = NotificationsState(
            becomeActiveObserver: didBecomeActiveObserver,
            resignActiveObserver: willResignActiveObserver,
            center: self.notificationCenter
          )
        }
      }
      return QuerySubscription {
        state.withLock { state in
          guard let state else { return }
          state.center.removeObserver(state.becomeActiveObserver)
          state.center.removeObserver(state.resignActiveObserver)
        }
      }
    }
  }

  private struct NotificationsState: @unchecked Sendable {
    let becomeActiveObserver: any NSObjectProtocol
    let resignActiveObserver: any NSObjectProtocol
    let center: NotificationCenter
  }

  // MARK: - NSApplication

  #if os(macOS)
    @MainActor
    public struct NSApplicationActivityObserver: DarwinApplicationActivityObserver {
      public static var didBecomeActiveNotification: Notification.Name {
        NSApplication.didBecomeActiveNotification
      }

      public static var willResignActiveNotification: Notification.Name {
        NSApplication.willResignActiveNotification
      }

      public var isInitiallyActive: Bool {
        NSApplication.shared.isActive
      }
    }

    extension ApplicationActivityObserver where Self == NSApplicationActivityObserver {
      public static var nsApplication: Self {
        NSApplicationActivityObserver()
      }
    }
  #endif

  // MARK: - WatchOS

  #if os(watchOS)
    @MainActor
    @available(watchOS 7.0, *)
    public struct WKApplicationActivityObserver: DarwinApplicationActivityObserver {
      public static var didBecomeActiveNotification: Notification.Name {
        WKApplication.didBecomeActiveNotification
      }

      public static var willResignActiveNotification: Notification.Name {
        WKApplication.willResignActiveNotification
      }

      public var isInitiallyActive: Bool {
        WKApplication.shared().applicationState == .active
      }
    }

    extension ApplicationActivityObserver where Self == WKApplicationActivityObserver {
      public static var wkApplication: Self {
        WKApplicationActivityObserver()
      }
    }

    @MainActor
    @available(watchOS 7.0, *)
    public struct WKExtensionActivityObserver: DarwinApplicationActivityObserver {
      public static var didBecomeActiveNotification: Notification.Name {
        WKExtension.applicationDidBecomeActiveNotification
      }

      public static var willResignActiveNotification: Notification.Name {
        WKExtension.applicationWillResignActiveNotification
      }

      public var isInitiallyActive: Bool {
        WKExtension.shared().applicationState == .active
      }
    }

    extension ApplicationActivityObserver where Self == WKExtensionActivityObserver {
      public static var wkExtension: Self {
        WKExtensionActivityObserver()
      }
    }
  #endif

  // MARK: - UIApplication

  #if os(iOS) || os(tvOS) || os(visionOS)
    @MainActor
    public struct UIApplicationActivityObserver: DarwinApplicationActivityObserver {
      public static var didBecomeActiveNotification: Notification.Name {
        UIApplication.didBecomeActiveNotification
      }

      public static var willResignActiveNotification: Notification.Name {
        UIApplication.willResignActiveNotification
      }

      public var isInitiallyActive: Bool {
        UIApplication.shared.applicationState == .active
      }
    }

    extension ApplicationActivityObserver where Self == UIApplicationActivityObserver {
      public static var uiApplication: Self {
        UIApplicationActivityObserver()
      }
    }
  #endif
#endif
