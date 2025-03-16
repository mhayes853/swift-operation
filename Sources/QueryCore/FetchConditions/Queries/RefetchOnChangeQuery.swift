extension QueryProtocol {
  public func refetchOnChange(
    of condition: some FetchCondition
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.controlled(by: RefetchOnChangeController(condition: condition))
  }
}

private final class RefetchOnChangeController<
  State: QueryStateProtocol,
  Condition: FetchCondition
>: QueryController {
  private let condition: Condition
  private let subscriptions = QuerySubscriptions<QueryControls<State>>()

  init(condition: Condition) {
    self.condition = condition
  }

  func control(with controls: QueryControls<State>) -> QuerySubscription {
    let (controlsSubscription, isFirst) = self.subscriptions.add(handler: controls)
    let conditionSubscription = isFirst ? self.subscribeToCondition(in: controls.context) : nil
    return QuerySubscription {
      if self.subscriptions.count == 0 {
        conditionSubscription?.cancel()
      }
      controlsSubscription.cancel()
    }
  }

  private func subscribeToCondition(
    in context: QueryContext
  ) -> QuerySubscription {
    let currentValue = Lock(self.condition.isSatisfied(in: context))
    return self.condition.subscribe(in: context) { newValue in
      currentValue.withLock { currentValue in
        defer { currentValue = newValue }
        guard newValue && (newValue != currentValue) else { return }
        Task {
          await withTaskGroup(of: Void.self) { group in
            self.subscriptions.forEach { controls in
              group.addTask { _ = try? await controls.yieldRefetch() }
            }
          }
        }
      }
    }
  }
}
