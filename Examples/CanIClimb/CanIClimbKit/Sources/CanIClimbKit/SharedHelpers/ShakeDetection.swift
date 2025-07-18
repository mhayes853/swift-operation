import Foundation
import SwiftUI

// MARK: - Notification Message

public struct DeviceShakeMessage: NotificationCenter.MainActorMessage {
  public typealias Subject = AnyObject
  public init() {}
}

// MARK: - View Modifier

#if os(iOS)
  extension View {
    public func shakeDetection() -> some View {
      self.background(ShakeDetectionView.Representable())
    }
  }

  private final class ShakeDetectionView: UIView {
    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      self.becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
      if motion == .motionShake {
        NotificationCenter.default.post(DeviceShakeMessage())
      }
    }
  }

  extension ShakeDetectionView {
    struct Representable: UIViewRepresentable {
      func makeUIView(context: Context) -> ShakeDetectionView {
        ShakeDetectionView()
      }

      func updateUIView(_ uiView: ShakeDetectionView, context: Context) {}
    }
  }
#endif
