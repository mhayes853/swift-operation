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
  public func refetchOnChange<Condition: FetchCondition>(
    of condition: Condition
  ) -> ControlledOperation<Self, _RefetchOnChangeController<State, Condition>> {
    self.controlled(by: _RefetchOnChangeController(condition: condition))
  }
}

public final class _RefetchOnChangeController<
  State: OperationState,
  Condition: FetchCondition
>: OperationController {
  private let condition: Condition
  private let subscriptions = OperationSubscriptions<OperationControls<State>>()
  private let task = Lock<Task<Void, any Error>?>(nil)

  init(condition: Condition) {
    self.condition = condition
  }

  public func control(with controls: OperationControls<State>) -> OperationSubscription {
    let (controlsSubscription, _) = self.subscriptions.add(handler: controls)
    let conditionSubscription = self.subscribeToCondition(in: controls.context)
    return .combined(controlsSubscription, conditionSubscription)
  }

  private func subscribeToCondition(
    in context: OperationContext
  ) -> OperationSubscription {
    let currentValue = Lock(self.condition.isSatisfied(in: context))
    return self.condition.subscribe(in: context) { newValue in
      let didValueChange = currentValue.withLock { currentValue in
        defer { currentValue = newValue }
        return newValue != currentValue
      }
      guard didValueChange else { return }
      if newValue {
        self.task.withLock { $0 = Task { try await self.refetchIfAble() } }
      } else {
        self.task.withLock { $0?.cancel() }
      }
    }
  }

  private func refetchIfAble() async throws {
    await withTaskGroup(of: Void.self) { group in
      self.subscriptions.forEach { controls in
        controls.withExclusiveAccess { controls in
          guard controls.subscriberCount > 0 && controls.isStale else { return }
          group.addTask { _ = try? await controls.yieldRefetch() }
        }
      }
    }
  }
}
