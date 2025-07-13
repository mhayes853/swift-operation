#if os(iOS)
  import UIKit
  import UIKitNavigation

  // MARK: - CanIClimbAlertController

  final class CanIClimbAlertController: UIAlertController {
    private var window: UIWindow?
  }

  extension CanIClimbAlertController {
    func present() {
      let window = self.currentWindow()
      window?.makeKeyAndVisible()
      window?.rootViewController?.present(self, animated: true)
    }
    
    private func currentWindow() -> UIWindow? {
      if let window {
        return window
      }
      let windowScene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first
      guard let windowScene else { return nil }
      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = UIViewController()
      window.windowLevel = .alert
      self.window = window
      return window
    }
  }

  extension CanIClimbAlertController {
    static func withOkButton<Action>(
      state: AlertState<Action>,
      handler: @escaping (_ action: Action?) -> Void = { (_: Never?) in }
    ) -> CanIClimbAlertController {
      var state = state
      if state.buttons.isEmpty {
        state.buttons.append(ButtonState { TextState("OK") })
      }
      return CanIClimbAlertController(state: state, handler: handler)
    }
  }

  // MARK: - TopMostViewController

  extension UIApplication {
    var topMostViewController: UIViewController? {
      let scene = self.connectedScenes.first as? UIWindowScene
      let rootVc = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
      return self.topMostViewController(controller: rootVc)
    }

    private func topMostViewController(controller: UIViewController?) -> UIViewController? {
      if let navigationController = controller as? UINavigationController {
        return self.topMostViewController(controller: navigationController.visibleViewController)
      }
      if let tabController = controller as? UITabBarController {
        if let selected = tabController.selectedViewController {
          return self.topMostViewController(controller: selected)
        }
      }
      if let presented = controller?.presentedViewController {
        return self.topMostViewController(controller: presented)
      }
      return controller
    }
  }
#endif
