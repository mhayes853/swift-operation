extension StatefulOperationRequest {
  /// Reruns this operation when the specified ``OperationRunSpecification`` changes to be
  /// satisfied.
  ///
  /// This modifier is used to power automatic rerunning when your app re-enters the foreground
  /// from the background, and automatic rerunning when the user's network connection comes back
  /// online.
  ///
  /// The operation is only rerun if all of these conditions hold:
  /// 1. `specification` changes its value to true.
  /// 2. The store backed by the operation must have at least 1 subscriber.
  /// 3. The ``OperationStore/isStale`` must be true for the store backed by this operation.
  /// 4. ``OperationStore/isAutomaticRunningEnabled`` is true for the store backed by this
  /// operation.
  ///
  /// - Parameter specification: The ``OperationRunSpecification`` to observe for rerunning.
  /// - Returns: A ``ModifiedOperation``.
  public func rerunOnChange<Specification>(
    of specification: Specification
  ) -> ControlledOperation<Self, _RerunOnChangeController<State, Specification>> {
    self.controlled(by: _RerunOnChangeController(specification: specification))
  }
}

public final class _RerunOnChangeController<
  State: OperationState & Sendable,
  Specification: OperationRunSpecification & Sendable
>: OperationController, Sendable {
  private let specification: Specification
  private let task = Lock<Task<Void, any Error>?>(nil)
  private let state = Lock([OperationPath: ControlsState]())

  init(specification: Specification) {
    self.specification = specification
  }

  public func control(with controls: OperationControls<State>) -> OperationSubscription {
    let path = controls.path
    self.state.withLock {
      $0[path] = ControlsState(
        controls: controls,
        currentValue: self.specification.isSatisfied(in: controls.context)
      )
    }
    let specSubscription = self.subscribeToSpec(with: path, in: controls.context)
    return OperationSubscription {
      _ = self.state.withLock { $0.removeValue(forKey: path) }
      specSubscription.cancel()
    }
  }

  private func subscribeToSpec(
    with path: OperationPath,
    in context: OperationContext
  ) -> OperationSubscription {
    self.specification.subscribe(in: context) { [weak self] in
      guard let self else { return }
      self.state.withLock { $0[path]?.onChange(of: self.specification) }
    }
  }
}

extension _RerunOnChangeController {
  private struct ControlsState: Sendable {
    let controls: OperationControls<State>
    var currentValue: Bool
    var task: Task<Void, any Error>?

    mutating func onChange(of specification: Specification) {
      let oldValue = self.currentValue
      self.currentValue = specification.isSatisfied(in: self.controls.context)
      let shouldRun = self.controls.withExclusiveAccess {
        $0.subscriberCount > 0 && $0.isStale && self.currentValue != oldValue
      }
      if shouldRun && self.currentValue {
        self.task = Task { [controls = self.controls] in try await controls.yieldRerun() }
      } else {
        self.task?.cancel()
      }
    }
  }
}
