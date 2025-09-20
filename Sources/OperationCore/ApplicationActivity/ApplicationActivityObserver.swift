import Foundation

// MARK: - ApplicationActivityObserver

/// A protocol for observing when the application becomes active (foreground) or inactive
/// (background).
public protocol ApplicationActivityObserver {
  /// Subscribes to the observer for the latest changes in the application's activity state.
  ///
  /// When this method is called, make sure to immediately invoke the handler with the current
  /// activity state of the observer.
  ///
  /// - Parameter handler: A closure that will be called when the application becomes active or
  ///   inactive.
  /// - Returns: An ``OperationSubscription``.
  func subscribe(_ handler: @escaping @Sendable (Bool) -> Void) -> OperationSubscription
}
