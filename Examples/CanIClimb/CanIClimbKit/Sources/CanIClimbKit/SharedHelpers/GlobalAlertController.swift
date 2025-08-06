#if os(iOS)
  import UIKit
  import UIKitNavigation

  // MARK: - GlobalAlertController

  public final class GlobalAlertController: UIAlertController {
    private var window: UIWindow?

    public static func withOkButton<Action>(
      state: AlertState<Action>,
      handler: @escaping (_ action: Action?) -> Void = { (_: Never?) in }
    ) -> GlobalAlertController {
      var state = state
      if state.buttons.isEmpty {
        state.buttons.append(ButtonState { TextState("OK") })
      }
      return GlobalAlertController(state: state, handler: handler)
    }

    public func present() {
      guard let window = self.currentWindow() else { return }
      if let style = UIApplication.shared.firstKeyWindow?.overrideUserInterfaceStyle {
        self.overrideUserInterfaceStyle = style
      }
      window.makeKeyAndVisible()
      window.rootViewController?.present(self, animated: true)
    }

    private func currentWindow() -> UIWindow? {
      if let window {
        return window
      }
      let keyWindow = UIApplication.shared.firstKeyWindow
      guard let keyWindow, let windowScene = keyWindow.windowScene else { return nil }
      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = UIViewController()
      window.windowLevel = .alert
      self.window = window
      return window
    }
  }

  // MARK: - Key Window

  extension UIApplication {
    fileprivate var firstKeyWindow: UIWindow? {
      self.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first
    }
  }
#endif
