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
  package protocol DarwinApplicationActivityObserver: ApplicationActivityObserver, Sendable {
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
    ) -> OperationSubscription {
      let state = Lock<NotificationsState?>(nil)
      MainActor.runImmediatelyIfAble {
        state.withLock { state in
          handler(self.isInitiallyActive)
          state = NotificationsState(
            center: self.notificationCenter,
            didBecomeActiveNotification: Self.didBecomeActiveNotification,
            willResignActiveNotification: Self.willResignActiveNotification,
            handler: handler
          )
        }
      }
      return OperationSubscription { state.withLock { $0?.cancel() } }
    }
  }

  private final class NotificationsState {
    private let becomeActiveObserver: any NSObjectProtocol
    private let resignActiveObserver: any NSObjectProtocol
    private let center: NotificationCenter

    init(
      center: NotificationCenter,
      didBecomeActiveNotification: Notification.Name,
      willResignActiveNotification: Notification.Name,
      handler: @escaping @Sendable (Bool) -> Void
    ) {
      self.becomeActiveObserver = center.addObserver(
        forName: didBecomeActiveNotification,
        object: nil,
        queue: nil
      ) { _ in handler(true) }
      self.resignActiveObserver = center.addObserver(
        forName: willResignActiveNotification,
        object: nil,
        queue: nil
      ) { _ in handler(false) }
      self.center = center
    }

    func cancel() {
      self.center.removeObserver(becomeActiveObserver)
      self.center.removeObserver(resignActiveObserver)
    }
  }

  // MARK: - NSApplication

  #if os(macOS)
    /// An ``ApplicationActivityObserver`` that observes the application activity state from
    /// `NSApplication`.
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
    /// An ``ApplicationActivityObserver`` that observes the application activity state from
    /// `WKApplication`.
    @MainActor
    @available(watchOS 7.0, *)
    public struct WKApplicationActivityObserver: DarwinApplicationActivityObserver {
      public static nonisolated let shared = WKApplicationActivityObserver()
      
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

    /// An ``ApplicationActivityObserver`` that observes the application activity state from
    /// `WKExtension`.
    @MainActor
    @available(watchOS 7.0, *)
    public struct WKExtensionActivityObserver: DarwinApplicationActivityObserver {
      public static nonisolated let shared = WKExtensionActivityObserver()
      
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
  #endif

  // MARK: - UIApplication

  #if os(iOS) || os(tvOS) || os(visionOS)
    /// An ``ApplicationActivityObserver`` that observes the application activity state from
    /// `UIApplication`.
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
