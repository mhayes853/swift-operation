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

#if !os(WASI)
  // MARK: - FocusFetchCondition

  public final class NotificationFocusCondition: Sendable {
    private let didBecomeActive: Notification.Name
    private let willResignActive: Notification.Name
    private let isActive: @Sendable () -> Bool

    fileprivate init(
      didBecomeActive: Notification.Name,
      willResignActive: Notification.Name,
      isActive: @escaping @Sendable () -> Bool
    ) {
      self.didBecomeActive = didBecomeActive
      self.willResignActive = willResignActive
      self.isActive = isActive
    }
  }

  // MARK: - FetchConditionObserver Conformance

  extension NotificationFocusCondition: FetchCondition {
    public func isSatisfied(in context: QueryContext) -> Bool {
      self.isActive()
    }

    public func subscribe(
      in context: QueryContext,
      _ observer: @escaping @Sendable (Bool) -> Void
    ) -> QuerySubscription {
      nonisolated(unsafe) let didBecomeActiveObserver = NotificationCenter.default.addObserver(
        forName: self.didBecomeActive,
        object: nil,
        queue: nil
      ) { _ in observer(true) }
      nonisolated(unsafe) let willResignActiveObserver = NotificationCenter.default.addObserver(
        forName: self.willResignActive,
        object: nil,
        queue: nil
      ) { _ in observer(false) }
      return QuerySubscription {
        NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        NotificationCenter.default.removeObserver(willResignActiveObserver)
      }
    }
  }

  extension FetchCondition where Self == NotificationFocusCondition {
    #if os(iOS) || os(tvOS) || os(visionOS)
      public static var notificationFocus: Self {
        .notificationFocus(
          didBecomeActive: UIApplication.didBecomeActiveNotification,
          willResignActive: UIApplication.willResignActiveNotification,
          isActive: { MainActor.runSync { UIApplication.shared.applicationState == .active } }
        )
      }
    #elseif os(macOS)
      public static var notificationFocus: Self {
        .notificationFocus(
          didBecomeActive: NSApplication.didBecomeActiveNotification,
          willResignActive: NSApplication.willResignActiveNotification,
          isActive: { MainActor.runSync { NSApplication.shared.isActive } }
        )
      }
    #elseif os(watchOS)
      @available(watchOS 7.0, *)
      public static var notificationFocus: Self {
        .notificationFocus(
          didBecomeActive: WKExtension.applicationDidBecomeActiveNotification,
          willResignActive: WKExtension.applicationWillResignActiveNotification,
          isActive: { MainActor.runSync { WKExtension.shared().applicationState == .active } }
        )
      }
    #endif

    public static func notificationFocus(
      didBecomeActive: Notification.Name,
      willResignActive: Notification.Name,
      isActive: @escaping @Sendable () -> Bool
    ) -> Self {
      NotificationFocusCondition(
        didBecomeActive: didBecomeActive,
        willResignActive: willResignActive,
        isActive: isActive
      )
    }
  }
#endif
