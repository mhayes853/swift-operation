import Operation

extension OperationStore where State: _QueryStateProtocol {
  public func resetWaitingForAllActiveTasksToFinish() async {
    let tasks = self.activeTasks
    self.resetState()
    for t in tasks where t.hasStarted {
      _ = try? await t.runIfNeeded()
    }
  }
}
