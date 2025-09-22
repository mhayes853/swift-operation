// MARK: - ControlledOperation

/// A helper typealias for specifying that your operation is controlled by an ``OperationController``.
///
/// Use this typealias when you define an extension to ``StatefulOperationRequest`` that applies
/// your controller.
///
/// ```swift
/// extension StatefulOperationRequest {
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
  Operation: StatefulOperationRequest,
  Controller: OperationController<Operation.State>
> = ModifiedOperation<Operation, _OperationControllerModifier<Operation, Controller>>

// MARK: - StatefulOperationRequest

extension StatefulOperationRequest {
  /// Attaches an ``OperationController`` to this operation.
  ///
  /// - Parameter controller: The controller to attach.
  /// - Returns: A ``ModifiedOperation``.
  public func controlled<Controller: Sendable>(
    by controller: Controller
  ) -> ControlledOperation<Self, Controller> {
    self.modifier(_OperationControllerModifier(controller: controller))
  }
}

public struct _OperationControllerModifier<
  Operation: StatefulOperationRequest,
  Controller: OperationController<Operation.State> & Sendable
>: _ContextUpdatingOperationModifier {
  let controller: Controller

  public func setup(context: inout OperationContext) {
    context.operationControllers.append(self.controller)
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The ``OperationController``s attached to a ``StatefulOperationRequest``.
  ///
  /// You generally add controllers via the ``StatefulOperationRequest/controlled(by:)`` modifier.
  public var operationControllers: [any OperationController & Sendable] {
    get { self[OperationControllersKey.self] }
    set { self[OperationControllersKey.self] = newValue }
  }

  private enum OperationControllersKey: Key {
    static var defaultValue: [any OperationController & Sendable] { [] }
  }
}
