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
#endif
