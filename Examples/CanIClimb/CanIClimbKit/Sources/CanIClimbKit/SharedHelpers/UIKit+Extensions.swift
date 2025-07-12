#if os(iOS)
  import UIKit
  import UIKitNavigation

  // MARK: - With Ok Button

  extension UIAlertController {
    static func withOkButton<Action>(
      state: AlertState<Action>,
      handler: @escaping (_ action: Action?) -> Void = { (_: Never?) in }
    ) -> UIAlertController {
      var state = state
      if state.buttons.isEmpty {
        state.buttons.append(ButtonState { TextState("OK") })
      }
      return UIAlertController(state: state, handler: handler)
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
