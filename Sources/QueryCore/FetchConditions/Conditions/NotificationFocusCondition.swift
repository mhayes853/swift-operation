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
    private let center: NotificationCenter

    fileprivate init(
      didBecomeActive: Notification.Name,
      willResignActive: Notification.Name,
      center: NotificationCenter = .default,
      isActive: @escaping @Sendable () -> Bool
    ) {
      self.didBecomeActive = didBecomeActive
      self.willResignActive = willResignActive
      self.isActive = isActive
      self.center = center
    }
  }

  // MARK: - FetchConditionObserver Conformance

  extension NotificationFocusCondition: FetchCondition {
    public func isSatisfied(in context: QueryContext) -> Bool {
      context.isFocusRefetchingEnabled && self.isActive()
    }

    public func subscribe(
      in context: QueryContext,
      _ observer: @escaping @Sendable (Bool) -> Void
    ) -> QuerySubscription {
      guard context.isFocusRefetchingEnabled else {
        observer(false)
        return .empty
      }

      nonisolated(unsafe) let didBecomeActiveObserver = self.center.addObserver(
        forName: self.didBecomeActive,
        object: nil,
        queue: nil
      ) { _ in observer(true) }
      nonisolated(unsafe) let willResignActiveObserver = self.center.addObserver(
        forName: self.willResignActive,
        object: nil,
        queue: nil
      ) { _ in observer(false) }
      return QuerySubscription {
        self.center.removeObserver(didBecomeActiveObserver)
        self.center.removeObserver(willResignActiveObserver)
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
          isActive: { MainActor.unsafeRunSync { UIApplication.shared.applicationState == .active } }
        )
      }
    #elseif os(macOS)
      /// A ``FetchCondition`` that is statisfied when `NSApplication` indicates that the app
      /// is active.
      public static var notificationFocus: Self {
        .notificationFocus(
          didBecomeActive: NSApplication.didBecomeActiveNotification,
          willResignActive: NSApplication.willResignActiveNotification,
          isActive: { MainActor.unsafeRunSync { NSApplication.shared.isActive } }
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
          isActive: { MainActor.unsafeRunSync { WKExtension.shared().applicationState == .active } }
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
            isActive: {
              MainActor.unsafeRunSync { WKApplication.shared().applicationState == .active }
            }
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
    ///   - center: The `NotificationCenter` instance to use to listen for the notifications.
    ///   - isActive: A predicate checking whether or not the app is active.
    /// - Returns: A ``NotificationFocusCondition``.
    public static func notificationFocus(
      didBecomeActive: Notification.Name,
      willResignActive: Notification.Name,
      center: NotificationCenter = .default,
      isActive: @escaping @Sendable () -> Bool
    ) -> Self {
      NotificationFocusCondition(
        didBecomeActive: didBecomeActive,
        willResignActive: willResignActive,
        center: center,
        isActive: isActive
      )
    }
  }
#endif
