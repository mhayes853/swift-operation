extension QueryRequest {
  /// Refetches this query when the specified ``FetchCondition`` changes to true.
  ///
  /// This modifier is used to power automatic refetching when your app re-enters from the
  /// background, and automatic fetching when the user's network connection comes back online.
  ///
  /// This query is only refetched if all of these conditions hold:
  /// 1. `condition` changes its value to true.
  /// 2. The query must have at least 1 subscriber.
  /// 3. The query must be stale.
  /// 4. Automatic fetching is enabled for this query.
  ///
  /// - Parameter condition: The ``FetchCondition`` to observe for query refetching.
  /// - Returns: A ``ModifiedQuery``.
  public func refetchOnChange<Condition: FetchCondition>(
    of condition: Condition
  ) -> ModifiedQuery<
    Self, _QueryControllerModifier<Self, _RefetchOnChangeController<State, Condition>>
  > {
    self.controlled(by: _RefetchOnChangeController(condition: condition))
  }
}

public final class _RefetchOnChangeController<
  State: QueryStateProtocol,
  Condition: FetchCondition
>: QueryController {
  private let condition: Condition
  private let subscriptions = QuerySubscriptions<QueryControls<State>>()
  private let task = Lock<Task<Void, any Error>?>(nil)

  init(condition: Condition) {
    self.condition = condition
  }

  public func control(with controls: QueryControls<State>) -> QuerySubscription {
    let (controlsSubscription, _) = self.subscriptions.add(handler: controls)
    let conditionSubscription = self.subscribeToCondition(in: controls.context)
    return .combined(controlsSubscription, conditionSubscription)
  }

  private func subscribeToCondition(
    in context: QueryContext
  ) -> QuerySubscription {
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
        guard controls.subscriberCount > 0 && controls.isStale else { return }
        group.addTask { _ = try? await controls.yieldRefetch() }
      }
    }
  }
}
