extension OperationRequest {
  /// Refetches this operation when the specified ``FetchCondition`` changes to true.
  ///
  /// This modifier is used to power automatic refetching when your app re-enters from the
  /// background, and automatic fetching when the user's network connection comes back online.
  ///
  /// This operation is only refetched if all of these conditions hold:
  /// 1. `condition` changes its value to true.
  /// 2. The operation must have at least 1 subscriber.
  /// 3. The operation must be stale.
  /// 4. Automatic fetching is enabled for this operation.
  ///
  /// - Parameter condition: The ``FetchCondition`` to observe for operation refetching.
  /// - Returns: A ``ModifiedOperation``.
  public func rerunOnChange<Specification>(
    of specification: Specification
  ) -> ControlledOperation<Self, _RerunOnChangeController<State, Specification>> {
    self.controlled(by: _RerunOnChangeController(specification: specification))
  }
}

public final class _RerunOnChangeController<
  State: OperationState,
  Specification: OperationRunSpecification & Sendable
>: OperationController {
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
