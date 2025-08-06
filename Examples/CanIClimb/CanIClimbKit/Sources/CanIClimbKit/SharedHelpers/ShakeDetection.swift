import Foundation
import SwiftUI

// MARK: - Notification Message

public struct DeviceShakeMessage: NotificationCenter.MainActorMessage {
  public typealias Subject = AnyObject
  public init() {}
}

// MARK: - View Modifier

#if os(iOS)
  extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
      if motion == .motionShake {
        NotificationCenter.default.post(DeviceShakeMessage())
      }
    }
  }

// extension View {
//   public func shakeDetection() -> some View {
//     self.overlay(ShakeDetectionViewController.Representable().allowsHitTesting(false))
//   }
// }

// private final class ShakeDetectionViewController: UIViewController {
//   override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
//     if motion == .motionShake {
//       NotificationCenter.default.post(DeviceShakeMessage())
//     }
//   }
// }

// extension ShakeDetectionViewController {
//   struct Representable: UIViewControllerRepresentable {
//     func makeUIViewController(context: Context) -> ShakeDetectionViewController {
//       ShakeDetectionViewController()
//     }

//     func updateUIViewController(
//       _ uiViewController: ShakeDetectionViewController,
//       context: Context
//     ) {}
//   }
// }
#endif
