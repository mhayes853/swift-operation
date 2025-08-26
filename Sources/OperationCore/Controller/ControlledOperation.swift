// MARK: - ControlledOperation

/// A helper typealias for specifying that your operation is controlled by a ``OperationController``.
///
/// Use this typealias when you define an extension to ``OperationRequest`` that applies your
/// controller.
///
/// ```swift
/// extension OperationRequest {
///   func myControlled() -> ControlledOperation<Self, MyController<State>> {
///     self.controlled(by: MyController())
///   }
/// }
///
/// final class MyController<State: OperationState>: OperationController {
///   // ...
/// }
/// ```
public typealias ControlledOperation<
  Operation: OperationRequest,
  Controller: OperationController<Operation.State>
> = ModifiedOperation<Operation, _OperationControllerModifier<Operation, Controller>>

// MARK: - OperationRequest

extension OperationRequest {
  /// Attaches a ``OperationController`` to this operation.
  ///
  /// - Parameter controller: The controller to attach.
  /// - Returns: A ``ModifiedOperation``.
  public func controlled<Controller: OperationController<State>>(
    by controller: Controller
  ) -> ControlledOperation<Self, Controller> {
    self.modifier(_OperationControllerModifier(controller: controller))
  }
}

public struct _OperationControllerModifier<
  Operation: OperationRequest,
  Controller: OperationController<Operation.State>
>: _ContextUpdatingOperationModifier {
  let controller: Controller

  public func setup(context: inout OperationContext) {
    context.operationControllers.append(self.controller)
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The ``OperationController``s attached to a ``OperationRequest``.
  ///
  /// You generally add controllers via the ``OperationRequest/controlled(by:)`` modifier.
  public var operationControllers: [any OperationController] {
    get { self[OperationControllersKey.self] }
    set { self[OperationControllersKey.self] = newValue }
  }

  private enum OperationControllersKey: Key {
    static var defaultValue: [any OperationController] { [] }
  }
}
