/// A protocol describing a condition for when ``OperationRequest`` should fetch its data.
///
/// Fetch conditions power many features of the library such as: Automatically refetching your
/// queries when the app re-enters from the background, automatically refetching when the user's
/// network connection comes back online, and much more. See <doc:UtilizingFetchConditions> to
/// learn about the vast variety of use cases for Fetch Conditions.
///
/// When conforming to the `FetchCondition` protocol, make sure your conformance always has the
/// most up to date value on whether or not it has been satisfied regardless of whether or not
/// there are subscribers attached to your condition.
public protocol OperationRunSpecification {
  /// Returns whether or not this condition is satisfied in the specified ``OperationContext``.
  ///
  /// - Parameter context: The context in which to evaluate this condition.
  /// - Returns: Whether or not the condition is satisfied.
  func isSatisfied(in context: OperationContext) -> Bool

  /// Subcribes to this condition in the specified ``OperationContext``.
  ///
  /// - Parameters:
  ///   - context: The context in which to subscribe to this condition in.
  ///   - observer: A callback to invoke whenever your condition's value changes.
  /// - Returns: A ``OperationSubscription``.
  func subscribe(
    in context: OperationContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> OperationSubscription
}
