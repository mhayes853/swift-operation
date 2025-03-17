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
    let (controlsSubscription, _) = self.subscriptions.add(handler: controls)
    let conditionSubscription = self.subscribeToCondition(in: controls.context)
    return QuerySubscription {
      controlsSubscription.cancel()
      conditionSubscription.cancel()
    }
  }

  private func subscribeToCondition(
    in context: QueryContext
  ) -> QuerySubscription {
    let currentValue = Lock(self.condition.isSatisfied(in: context))
    return self.condition.subscribe(in: context) { newValue in
      let shouldRefetch = currentValue.withLock { currentValue in
        defer { currentValue = newValue }
        return newValue && (newValue != currentValue)
      }
      guard shouldRefetch else { return }
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
