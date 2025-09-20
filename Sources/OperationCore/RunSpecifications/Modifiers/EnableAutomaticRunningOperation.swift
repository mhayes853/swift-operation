// MARK: - StatefulOperationRequest

extension StatefulOperationRequest {
  /// Disables automatic running for this operation based on whether or not `isDisabled` is true.
  ///
  /// Automatic running is defined as the process of running this operation without explicitly
  /// calling ``OperationStore/run(using:handler:)``. This includes, but not limited to:
  /// 1. Running when subscribed to via ``OperationStore/subscribe(with:)-(OperationEventHandler<State>)``.
  /// 2. Running when the app re-enters the foreground from the background.
  /// 3. Running when the user's network connection flips from offline to online.
  /// 4. Running via an ``OperationController``.
  /// 5. Running via the ``StatefulOperationRequest/rerunOnChange(of:)`` modifier.
  ///
  /// When automatic running is disabled, you are responsible for manually calling
  /// ``OperationStore/run(using:handler:)`` to ensure that your operation always has the latest
  /// data. Methods that work on specific operation types such as
  /// ``OperationStore/mutate(using:handler:)`` will call ``OperationStore/run(using:handler:)``
  /// under the hood for you.
  ///
  /// When you use the default initializer of a ``OperationClient``, automatic running is enabled for all
  /// stores backed by ``QueryRequest`` and ``PaginatedRequest`` operations, and disabled for all
  /// stores backed by ``MutationRequest`` operations.
  ///
  /// - Parameter isDisabled: Whether or not to disable automatic running.
  /// - Returns: A ``ModifiedOperation``.
  public func disableAutomaticRunning(
    _ isDisabled: Bool = true
  ) -> ModifiedOperation<Self, _EnableAutomaticFetchingModifier<Self, AlwaysRunSpecification>> {
    self.enableAutomaticRunning(onlyWhen: .always(!isDisabled))
  }

  /// Enables automatic running for this operation based on the satisfication of the specified
  /// ``OperationRunSpecification``.
  ///
  /// Automatic running is defined as the process of running this operation without explicitly
  /// calling ``OperationStore/run(using:handler:)``. This includes, but not limited to:
  /// 1. Running when subscribed to via ``OperationStore/subscribe(with:)-(OperationEventHandler<State>)``.
  /// 2. Running when the app re-enters the foreground from the background.
  /// 3. Running when the user's network connection flips from offline to online.
  /// 4. Running via an ``OperationController``.
  /// 5. Running via the ``StatefulOperationRequest/rerunOnChange(of:)`` modifier.
  ///
  /// When automatic running is disabled, you are responsible for manually calling
  /// ``OperationStore/run(using:handler:)`` to ensure that your operation always has the latest
  /// data. Methods that work on specific operation types such as
  /// ``OperationStore/mutate(using:handler:)`` will call ``OperationStore/run(using:handler:)``
  /// under the hood for you.
  ///
  /// When you use the default initializer of a ``OperationClient``, automatic running is enabled for all
  /// stores backed by ``QueryRequest`` and ``PaginatedRequest`` operations, and disabled for all
  /// stores backed by ``MutationRequest`` operations.
  ///
  /// - Parameter specification: The ``OperationRunSpecification`` to determine whether or not
  ///   automatic running is enabled.
  /// - Returns: A ``ModifiedOperation``.
  public func enableAutomaticRunning<Specification>(
    onlyWhen specification: Specification
  ) -> ModifiedOperation<Self, _EnableAutomaticFetchingModifier<Self, Specification>> {
    self.modifier(_EnableAutomaticFetchingModifier(specification: specification))
  }
}

public struct _EnableAutomaticFetchingModifier<
  Operation: OperationRequest,
  Specification: OperationRunSpecification & Sendable
>: _ContextUpdatingOperationModifier {
  let specification: Specification

  public func setup(context: inout OperationContext) {
    context.automaticRunningSpecification = self.specification
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The ``OperationRunSpecification`` that determines whether or not automatic runing is enabled
  /// for an operation.
  ///
  /// You can set the value of this property through the
  /// ``StatefulOperationRequest/enableAutomaticRunning(onlyWhen:)`` and
  /// ``StatefulOperationRequest/disableAutomaticRunning(_:)`` modifiers.
  ///
  /// The default value of this context property is a specification that always returns false.
  /// However, if you use the default initializer of a ``OperationClient``, then the default value
  /// will be a specification that is true for all ``OperationStore`` instances backed by
  /// ``QueryRequest`` and ``PaginatedRequest`` operations, and always false for stores backed
  /// by ``MutationRequest`` operations.
  public var automaticRunningSpecification: any OperationRunSpecification & Sendable {
    get { self[AutomaticRunningSpecificiationKey.self] }
    set { self[AutomaticRunningSpecificiationKey.self] = newValue }
  }

  private enum AutomaticRunningSpecificiationKey: Key {
    static var defaultValue: any OperationRunSpecification & Sendable {
      AlwaysRunSpecification(isTrue: false)
    }
  }
}
