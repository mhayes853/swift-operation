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
  public final class ApplicationIsActiveCondition: Sendable {
    private typealias Handler = @Sendable (Bool) -> Void
    private struct State: @unchecked Sendable {
      let becomeActiveObserver: any NSObjectProtocol
      let resignActiveObserver: any NSObjectProtocol
      var isActive: Bool
    }

    private let state = Lock<State?>(nil)
    private let subscriptions = QuerySubscriptions<Handler>()
    private let center: NotificationCenter

    fileprivate init<Observer: ApplicationActivityObserver>(
      observer: @MainActor @escaping @autoclosure () -> Observer,
      center: NotificationCenter = .default
    ) {
      self.center = center
      MainActor.runSyncIfAble {
        let observer = observer()
        self.state.withLock { state in
          let didBecomeActiveObserver = center.addObserver(
            forName: Observer.didBecomeActiveNotification,
            object: nil,
            queue: nil
          ) { _ in
            self.state.withLock { state in
              state?.isActive = true
              self.subscriptions.forEach { $0(true) }
            }
          }
          let willResignActiveObserver = center.addObserver(
            forName: Observer.willResignActiveNotification,
            object: nil,
            queue: nil
          ) { _ in
            self.state.withLock { state in
              state?.isActive = false
              self.subscriptions.forEach { $0(false) }
            }
          }
          state = State(
            becomeActiveObserver: didBecomeActiveObserver,
            resignActiveObserver: willResignActiveObserver,
            isActive: observer.isInitiallyActive
          )
        }
      }
    }

    deinit {
      self.state.withLock { state in
        guard let state else { return }
        self.center.removeObserver(state.becomeActiveObserver)
        self.center.removeObserver(state.resignActiveObserver)
      }
    }
  }

  // MARK: - FetchConditionObserver Conformance

  extension ApplicationIsActiveCondition: FetchCondition {
    public func isSatisfied(in context: QueryContext) -> Bool {
      self.state.withLock { state in
        context.isApplicationActiveRefetchingEnabled && (state?.isActive ?? true)
      }
    }

    public func subscribe(
      in context: QueryContext,
      _ observer: @escaping @Sendable (Bool) -> Void
    ) -> QuerySubscription {
      guard context.isApplicationActiveRefetchingEnabled else {
        observer(false)
        return .empty
      }
      return self.subscriptions.add(handler: observer).subscription
    }
  }

  extension FetchCondition where Self == ApplicationIsActiveCondition {
    #if os(iOS) || os(tvOS) || os(visionOS)
      /// A ``FetchCondition`` that is statisfied when `UIApplication` indicates that the app
      /// is active.
      public static var applicationIsActive: Self {
        .applicationIsActive(observer: UIApplication.shared)
      }
    #elseif os(macOS)
      /// A ``FetchCondition`` that is statisfied when `NSApplication` indicates that the app
      /// is active.
      public static var applicationIsActive: Self {
        .applicationIsActive(observer: NSApplication.shared)
      }
    #elseif os(watchOS)
      /// A ``FetchCondition`` that is statisfied when `WKExtension` indicates that the app
      /// is active.
      @available(watchOS 7.0, *)
      public static var applicationExtensionIsActive: Self {
        .applicationIsActive(observer: WKExtension.shared())
      }

      /// A ``FetchCondition`` that is statisfied when `WKApplication` indicates that the app
      /// is active.
      @available(watchOS 7.0, *)
      public static var applicationIsActive: Self {
        .applicationIsActive(observer: WKApplication.shared())
      }
    #endif

    @_spi(ApplicationActivityObserver)
    public static func applicationIsActive<Observer: ApplicationActivityObserver>(
      observer: @MainActor @escaping @autoclosure () -> Observer,
      center: NotificationCenter = .default
    ) -> Self {
      ApplicationIsActiveCondition(observer: observer(), center: center)
    }
  }
#endif
