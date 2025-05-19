#if !os(WASI)
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

  // MARK: - ApplicationActivityObserver

  @_spi(ApplicationActivityObserver)
  @MainActor
  public protocol ApplicationActivityObserver {
    static var didBecomeActiveNotification: Notification.Name { get }
    static var willResignActiveNotification: Notification.Name { get }

    var isInitiallyActive: Bool { get }
  }

  // MARK: - Platform Conformances

  #if os(macOS)
    @_spi(ApplicationActivityObserver)
    extension NSApplication: ApplicationActivityObserver {
      public var isInitiallyActive: Bool { self.isActive }
    }
  #elseif os(watchOS)
    @_spi(ApplicationActivityObserver)
    extension WKApplication: ApplicationActivityObserver {
      public var isInitiallyActive: Bool { self.applicationState == .active }
    }

    @_spi(ApplicationActivityObserver)
    extension WKExtension: ApplicationActivityObserver {
      public static var didBecomeActiveNotification: Notification.Name {
        WKExtension.applicationDidBecomeActiveNotification
      }

      public static var willResignActiveNotification: Notification.Name {
        WKExtension.applicationWillResignActiveNotification
      }

      public var isInitiallyActive: Bool { self.applicationState == .active }
    }
  #elseif os(iOS) || os(tvOS) || os(visionOS)
    @_spi(ApplicationActivityObserver)
    extension UIApplication: ApplicationActivityObserver {
      public var isInitiallyActive: Bool { self.applicationState == .active }
    }
  #endif
#endif
