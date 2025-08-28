import Operation

final class TestOperationController<Operation: OperationRequest>: OperationController {
  typealias State = Operation.State

  let controls = RecursiveLock<OperationControls<State>?>(nil)

  func control(with controls: OperationControls<State>) -> OperationSubscription {
    self.controls.withLock { $0 = controls }
    return OperationSubscription {
      self.controls.withLock { $0 = nil }
    }
  }
}
