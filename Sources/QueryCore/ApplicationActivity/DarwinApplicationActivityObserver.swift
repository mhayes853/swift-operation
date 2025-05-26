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
      package static var didBecomeActiveNotification: Notification.Name {
        NSApplication.didBecomeActiveNotification
      }

      package static var willResignActiveNotification: Notification.Name {
        NSApplication.willResignActiveNotification
      }

      package var isInitiallyActive: Bool {
        NSApplication.shared.isActive
      }

      public nonisolated init() {}
    }

    extension NSApplicationActivityObserver {
      public static nonisolated let shared = NSApplicationActivityObserver()
    }
  #endif

  // MARK: - WatchOS

  #if os(watchOS)
    @MainActor
    @available(watchOS 7.0, *)
    public struct WKApplicationActivityObserver: DarwinApplicationActivityObserver {
      package static var didBecomeActiveNotification: Notification.Name {
        WKApplication.didBecomeActiveNotification
      }

      package static var willResignActiveNotification: Notification.Name {
        WKApplication.willResignActiveNotification
      }

      package var isInitiallyActive: Bool {
        WKApplication.shared().applicationState == .active
      }

      public nonisolated init() {}
    }

    extension WKApplicationActivityObserver {
      public static nonisolated let shared = WKApplicationActivityObserver()
    }

    @MainActor
    @available(watchOS 7.0, *)
    public struct WKExtensionActivityObserver: DarwinApplicationActivityObserver {
      package static var didBecomeActiveNotification: Notification.Name {
        WKExtension.applicationDidBecomeActiveNotification
      }

      package static var willResignActiveNotification: Notification.Name {
        WKExtension.applicationWillResignActiveNotification
      }

      package var isInitiallyActive: Bool {
        WKExtension.shared().applicationState == .active
      }

      public nonisolated init() {}
    }

    extension WKExtensionActivityObserver {
      public static nonisolated let shared = WKExtensionActivityObserver()
    }
  #endif

  // MARK: - UIApplication

  #if os(iOS) || os(tvOS) || os(visionOS)
    @MainActor
    public struct UIApplicationActivityObserver: DarwinApplicationActivityObserver {
      package static var didBecomeActiveNotification: Notification.Name {
        UIApplication.didBecomeActiveNotification
      }

      package static var willResignActiveNotification: Notification.Name {
        UIApplication.willResignActiveNotification
      }

      package var isInitiallyActive: Bool {
        UIApplication.shared.applicationState == .active
      }

      public nonisolated init() {}
    }

    extension UIApplicationActivityObserver {
      public static nonisolated let shared = UIApplicationActivityObserver()
    }
  #endif
#endif
