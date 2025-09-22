/// A protocol describing a condition for when an ``OperationRequest`` should run.
///
/// Run specifications determine when an operation should run in a given context. This feature is
/// used to power may features of the library such as: Automatically rerunning operations when the
/// application reenters the foreground from the background, automatically rerunning operations
/// when the network connection flips from offline to online, and much more.
///
/// Run specifications should eagerly track whether or not they are satisfied. They should avoid
/// beginning such tracking only when ``subscribe(in:onChange:)`` is invoked for the first time.
/// This is because not all APIs in the library will need to directly subscribe to changes.
public protocol OperationRunSpecification {
  /// Returns whether or not this condition is satisfied in the specified ``OperationContext``.
  ///
  /// > Note: Make sure this method always reflects the latest value of the specification, even if
  /// > there are no subscribers. That is, you should eagerly track the latest value, and avoid
  /// > waiting until ``subscribe(in:onChange:)`` is called before beginning to track the current
  /// > value.
  /// >
  /// > This is because not all APIs in the library will need to directly subscribe to changes.
  ///
  /// - Parameter context: The context in which to evaluate this condition.
  /// - Returns: Whether or not the condition is satisfied.
  func isSatisfied(in context: OperationContext) -> Bool

  /// Subcribes to changes on this specification in the specified ``OperationContext``.
  ///
  /// Generally, ``isSatisfied(in:)`` will be invoked immediately after you indicate an update
  /// through `onChange`, so ensure that you have the latest value available before indicating an
  /// update.
  ///
  /// > Note: You should begin tracking the latest value of the specification eagerly such that
  /// > ``isSatisfied(in:)`` always returns the latest value regardless of whether or not the
  /// > specification has any active subscibers. Do not wait until this method is invoked to begin
  /// > tracking that latest value. This is because not all APIs in the library will need to
  /// > directly subscribe to changes.
  ///
  /// - Parameters:
  ///   - context: The context in which to subscribe to this condition in.
  ///   - onChange: A callback to invoke whenever your specification's value changes.
  /// - Returns: An ``OperationSubscription``.
  func subscribe(
    in context: OperationContext,
    onChange: @escaping @Sendable () -> Void
  ) -> OperationSubscription
}
