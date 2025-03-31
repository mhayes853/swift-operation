import Query

final class TestQueryController<Query: QueryRequest>: QueryController {
  typealias State = Query.State

  let controls = RecursiveLock<QueryControls<State>?>(nil)

  func control(with controls: QueryControls<State>) -> QuerySubscription {
    self.controls.withLock { $0 = controls }
    return QuerySubscription {
      self.controls.withLock { $0 = nil }
    }
  }
}
