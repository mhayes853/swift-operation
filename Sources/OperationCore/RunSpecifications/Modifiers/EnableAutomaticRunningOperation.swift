// MARK: - OperationRequest

extension OperationRequest {
  /// Disables automatic fetching for this query based on whether or not `isDisabled` is true.
  ///
  /// Automatic fetching is defined as the process of data being fetched from this query without
  /// explicitly calling ``OperationStore/fetch(using:handler:)``. This includes, but not limited to:
  /// 1. Automatically fetching from this query when subscribed to via ``OperationStore/subscribe(with:)-93jyd``.
  /// 2. Automatically fetching from this query when the app re-enters from the background.
  /// 3. Automatically fetching from this query when the user's network connection comes back online.
  /// 4. Automatically fetching from this query via a ``OperationController``.
  /// 5. Automatically fetching from this query via ``refetchOnChange(of:)``.
  ///
  /// When automatic fetching is disabled, you are responsible for manually calling
  /// ``OperationStore/fetch(using:handler:)`` to ensure that your query always has the latest data.
  ///
  /// When you use the default initializer of a ``OperationClient``, automatic fetching is enabled for all
  /// ``QueryRequest`` conformances, and disabled for all ``MutationRequest`` conformances.
  ///
  /// - Parameter isDisabled: Whether or not to disable automatic fetching.
  /// - Returns: A ``ModifiedOperation``.
  public func disableAutomaticRunning(
    _ isDisabled: Bool = true
  ) -> ModifiedOperation<Self, _EnableAutomaticFetchingModifier<Self, AlwaysRunSpecification>> {
    self.enableAutomaticRunning(onlyWhen: .always(!isDisabled))
  }

  /// Enables automatic fetching for this query based on the specified ``FetchCondition``.
  ///
  /// Automatic fetching is defined as the process of data being fetched from this query without
  /// explicitly calling ``OperationStore/fetch(using:handler:)``. This includes, but not limited to:
  /// 1. Automatically fetching from this query when subscribed to via ``OperationStore/subscribe(with:)-93jyd``.
  /// 2. Automatically fetching from this query when the app re-enters from the background.
  /// 3. Automatically fetching from this query when the user's network connection comes back online.
  /// 4. Automatically fetching from this query via a ``OperationController``.
  /// 5. Automatically fetching from this query via ``refetchOnChange(of:)``.
  ///
  /// When automatic fetching is disabled, you are responsible for manually calling
  /// ``OperationStore/fetch(using:handler:)`` to ensure that your query always has the latest data.
  ///
  /// When you use the default initializer of a ``OperationClient``, automatic fetching is enabled for all
  /// ``QueryRequest`` conformances, and disabled for all ``MutationRequest`` conformances.
  ///
  /// - Parameter condition: The ``FetchCondition`` to enable automatic fetching on.
  /// - Returns: A ``ModifiedOperation``.
  public func enableAutomaticRunning<Spec>(
    onlyWhen spec: Spec
  ) -> ModifiedOperation<Self, _EnableAutomaticFetchingModifier<Self, Spec>> {
    self.modifier(_EnableAutomaticFetchingModifier(spec: spec))
  }
}

public struct _EnableAutomaticFetchingModifier<
  Operation: OperationRequest,
  Specification: OperationRunSpecification & Sendable
>: _ContextUpdatingOperationModifier {
  let spec: Specification

  public func setup(context: inout OperationContext) {
    context.automaticRunningSpecification = self.spec
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The ``FetchCondition`` that determines whether or not automatic fetching is enabled for an
  /// operation.
  ///
  /// The default value of this context property is a condition that always returns false.
  /// However, if you use the default initializer of a ``OperationClient``, then the condition will have
  /// a default value of true for all ``QueryRequest`` conformances and false for all
  /// ``MutationRequest`` conformances.
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
