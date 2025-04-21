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

  /// A ``FetchCondition`` that is satisfied whenever the app is active in the foreground based on
  /// system notifications.
  ///
  /// The default instance of this condition uses platform-specific `Notification`s to observe
  /// the app lifecycle, and a check for whether or not the app's state is active.
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
      /// A ``FetchCondition`` that is statisfied when `UIApplication` indicates that the app
      /// is active.
      public static var notificationFocus: Self {
        .notificationFocus(
          didBecomeActive: UIApplication.didBecomeActiveNotification,
          willResignActive: UIApplication.willResignActiveNotification,
          isActive: { MainActor.runSync { UIApplication.shared.applicationState == .active } }
        )
      }
    #elseif os(macOS)
      /// A ``FetchCondition`` that is statisfied when `NSApplication` indicates that the app
      /// is active.
      public static var notificationFocus: Self {
        .notificationFocus(
          didBecomeActive: NSApplication.didBecomeActiveNotification,
          willResignActive: NSApplication.willResignActiveNotification,
          isActive: { MainActor.runSync { NSApplication.shared.isActive } }
        )
      }
    #elseif os(watchOS)
      /// A ``FetchCondition`` that is statisfied when `WKExtension` indicates that the app
      /// is active.
      @available(watchOS 7.0, *)
      public static var notificationExtensionFocus: Self {
        .notificationFocus(
          didBecomeActive: WKExtension.applicationDidBecomeActiveNotification,
          willResignActive: WKExtension.applicationWillResignActiveNotification,
          isActive: { MainActor.runSync { WKExtension.shared().applicationState == .active } }
        )
      }

      /// A ``FetchCondition`` that is statisfied when `WKApplication` indicates that the app
      /// is active.
      @available(watchOS 7.0, *)
      public static var notificationFocus: Self {
        MainActor.runSync {
          .notificationFocus(
            didBecomeActive: WKApplication.didBecomeActiveNotification,
            willResignActive: WKApplication.willResignActiveNotification,
            isActive: { MainActor.runSync { WKApplication.shared().applicationState == .active } }
          )
        }
      }
    #endif

    /// Creates a ``NotificationFocusCondition`` using a `Notification` for whenever the app
    /// becomes active and will resign being active, and a predicate that determines whether or
    /// not the app is in an active state.
    ///
    /// - Parameters:
    ///   - didBecomeActive: A `Notification` for whether or not the app became active.
    ///   - willResignActive: A `Notification` for whether or not the app will resign being active.
    ///   - isActive: A predicate checking whether or not the app is active.
    /// - Returns: A ``NotificationFocusCondition``.
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
