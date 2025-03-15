import QueryCore

final class TestQueryController<Query: QueryProtocol>: QueryController {
  typealias State = Query.State

  let controls = Lock<QueryControls<State>?>(nil)

  func control(with controls: QueryControls<State>) -> QuerySubscription {
    self.controls.withLock { $0 = controls }
    return QuerySubscription {
      self.controls.withLock { $0 = nil }
    }
  }
}
