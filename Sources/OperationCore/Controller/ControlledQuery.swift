// MARK: - ControlledQuery

/// A helper typealias for specifying that your query is controlled by a ``OperationController``.
///
/// Use this typealias when you define an extension to ``QueryRequest`` that applies your
/// controller.
///
/// ```swift
/// extension QueryRequest {
///   func myControlled() -> ControlledQuery<Self, MyController<State>> {
///     self.controlled(by: MyController())
///   }
/// }
///
/// final class MyController<State: OperationState>: OperationController {
///   // ...
/// }
/// ```
public typealias ControlledQuery<
  Query: QueryRequest,
  Controller: OperationController<Query.State>
> =
  ModifiedQuery<Query, _OperationControllerModifier<Query, Controller>>

// MARK: - QueryRequest

extension QueryRequest {
  /// Attaches a ``OperationController`` to this query.
  ///
  /// - Parameter controller: The controller to attach.
  /// - Returns: A ``ModifiedQuery``.
  public func controlled<Controller: OperationController<State>>(
    by controller: Controller
  ) -> ControlledQuery<Self, Controller> {
    self.modifier(_OperationControllerModifier(controller: controller))
  }
}

public struct _OperationControllerModifier<
  Query: QueryRequest,
  Controller: OperationController<Query.State>
>: _ContextUpdatingQueryModifier {
  let controller: Controller

  public func setup(context: inout OperationContext) {
    context.operationControllers.append(self.controller)
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The ``OperationController``s attached to a ``QueryRequest``.
  ///
  /// You generally add controllers via the ``QueryRequest/controlled(by:)`` modifier.
  public var operationControllers: [any OperationController] {
    get { self[OperationControllersKey.self] }
    set { self[OperationControllersKey.self] = newValue }
  }

  private enum OperationControllersKey: Key {
    static var defaultValue: [any OperationController] { [] }
  }
}
