// MARK: - OperationController

/// A protocol for controlling the state of a query.
///
/// OperationControllers represent reusable and composable pieces of logic that allow one to control
/// thet state of a query, and even automatically refetch a query. You can attach a `OperationController`
/// to a ``QueryRequest`` via the ``QueryRequest/controlled(by:)`` modifier.
///
/// See <doc:UtilizingOperationControllers> to learn more about the best practices and use cases for
/// OperationControllers.
public protocol OperationController<State>: Sendable {
  /// The state type of the query to control.
  associatedtype State: OperationState

  /// A method that hands the controls for a query to this controller.
  ///
  /// Here, you can subscribe to any external data sources, or store `controls` inside your
  /// controller for later use. The ``OperationSubscription`` that you return from this method is
  /// responsible for performing any cleanup work involved with `controls`.
  ///
  /// - Parameter controls: A ``OperationControls`` instance.
  /// - Returns: A ``OperationSubscription``.
  func control(with controls: OperationControls<State>) -> OperationSubscription
}
