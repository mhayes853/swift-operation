extension QueryRequest {
  public func refetchOnChange<Condition: FetchCondition>(
    of condition: Condition
  ) -> ModifiedQuery<
    Self, QueryControllerModifier<Self, RefetchOnChangeController<State, Condition>>
  > {
    self.controlled(by: RefetchOnChangeController(condition: condition))
  }
}

public final class RefetchOnChangeController<
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
