// MARK: - OperationController

/// A protocol for controlling the state of an operation.
///
/// Controllers represent reusable and composable pieces of logic that allow one to control
/// thet state of an operation, and even automatically run an operation. You can attach an
/// `OperationController` to a ``StatefulOperationRequest`` via the
/// ``StatefulOperationRequest/controlled(by:)`` modifier.
///
/// ```swift
/// // Automatically rerun an operation when a notification is posted from NotificationCenter.
///
/// extension StatefulOperationRequest {
///   func refetchOnPost(
///     of name: Notification.Name,
///     center: NotificationCenter = .default
///   ) -> ControlledOperation<Self, RefetchOnNotificationController<State>> {
///     self.controlled(by: RefetchOnNotificationController(notification: name, center: center))
///   }
/// }
///
/// struct RefetchOnNotificationController<State: OperationState>: OperationController {
///   let notification: Notification.Name
///   let center: NotificationCenter
///
///   func control(with controls: OperationControls<State>) -> OperationSubscription {
///     nonisolated(unsafe) let observer = self.center.addObserver(
///       forName: self.notification,
///       object: nil,
///       queue: nil
///     ) { _ in
///       let task = controls.yieldRerunTask()
///       Task { try await task?.runIfNeeded() }
///     }
///     return OperationSubscription { self.center.removeObserver(observer) }
///   }
/// }
/// ```
public protocol OperationController<State> {
  /// The state type of the operation to control.
  associatedtype State: OperationState & Sendable

  /// A method that hands the controls for an operation to this controller.
  ///
  /// Here, you can subscribe to any external data sources, or store `controls` inside your
  /// controller for later use. The ``OperationSubscription`` that you return from this method is
  /// responsible for performing any cleanup work involved with `controls`.
  ///
  /// - Parameter controls: An ``OperationControls`` instance.
  /// - Returns: An ``OperationSubscription``.
  func control(with controls: OperationControls<State>) -> OperationSubscription
}
