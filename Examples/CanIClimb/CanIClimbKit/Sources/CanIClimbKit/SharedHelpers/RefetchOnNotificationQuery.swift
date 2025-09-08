import Foundation
import Operation

extension StatefulOperationRequest where State: Sendable {
  public func refetchOnPost(
    of name: Notification.Name,
    center: NotificationCenter = .default
  ) -> ControlledOperation<Self, _RefetchOnPostController<State>> {
    self.controlled(by: _RefetchOnPostController(notification: name, center: center))
  }
}

public struct _RefetchOnPostController<
  State: OperationState & Sendable
>: OperationController, Sendable {
  let notification: Notification.Name
  let center: NotificationCenter

  public func control(with controls: OperationControls<State>) -> OperationSubscription {
    nonisolated(unsafe) let observer = self.center.addObserver(
      forName: self.notification,
      object: nil,
      queue: nil
    ) { _ in
      let task = controls.yieldRerunTask()
      Task { try await task?.runIfNeeded() }
    }
    return OperationSubscription { self.center.removeObserver(observer) }
  }
}
