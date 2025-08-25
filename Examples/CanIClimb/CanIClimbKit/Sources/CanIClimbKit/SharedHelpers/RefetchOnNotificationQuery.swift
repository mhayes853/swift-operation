import Foundation
import Operation

extension QueryRequest {
  public func refetchOnPost(
    of name: Notification.Name,
    center: NotificationCenter = .default
  ) -> ControlledQuery<Self, _RefetchOnNotificationController<State>> {
    self.controlled(by: _RefetchOnNotificationController(notification: name, center: center))
  }
}

public struct _RefetchOnNotificationController<State: OperationState>: OperationController {
  let notification: Notification.Name
  let center: NotificationCenter

  public func control(with controls: OperationControls<State>) -> OperationSubscription {
    nonisolated(unsafe) let observer = self.center.addObserver(
      forName: self.notification,
      object: nil,
      queue: nil
    ) { _ in
      let task = controls.yieldRefetchTask()
      Task { try await task?.runIfNeeded() }
    }
    return OperationSubscription { self.center.removeObserver(observer) }
  }
}
