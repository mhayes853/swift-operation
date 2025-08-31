import CustomDump
import Operation
import Testing

@Suite("NetworkConnectionRunSpecification tests")
struct NetworkConnectionRunSpecificationTests {
  @Test(
    "Default Satisfied When Status",
    arguments: [
      (NetworkConnectionStatus.disconnected, false),
      (.connected, true),
      (.requiresConnection, false)
    ]
  )
  func satisfiedWhenStatus(status: NetworkConnectionStatus, isSatisfied: Bool) {
    let observer = MockNetworkObserver()
    let c: some OperationRunSpecification = .connected(to: observer)
    observer.send(status: status)
    expectNoDifference(c.isSatisfied(in: OperationContext()), isSatisfied)
  }

  @Test(
    "Default Satisfied When Status For Context Value",
    arguments: [
      (NetworkConnectionStatus.disconnected, false),
      (.connected, true),
      (.requiresConnection, true)
    ]
  )
  func satisfiedWhenStatusForContextValue(status: NetworkConnectionStatus, isSatisfied: Bool) {
    var context = OperationContext()
    context.satisfiedConnectionStatus = .requiresConnection
    let observer = MockNetworkObserver()
    let c: some OperationRunSpecification = .connected(to: observer)
    observer.send(status: status)
    expectNoDifference(c.isSatisfied(in: context), isSatisfied)
  }

  @Test(
    "Default Observes When Status",
    arguments: [
      (NetworkConnectionStatus.disconnected, false),
      (.connected, true),
      (.requiresConnection, false)
    ]
  )
  func observesWhenStatus(status: NetworkConnectionStatus, isSatisfied: Bool) {
    let satisfactions = RecursiveLock([Bool]())
    let observer = MockNetworkObserver()
    let c: some OperationRunSpecification = .connected(to: observer)
    let subscription = c.subscribe(in: OperationContext()) { satisfied in
      satisfactions.withLock { $0.append(satisfied) }
    }
    observer.send(status: status)
    satisfactions.withLock { expectNoDifference($0, [true, isSatisfied]) }
    subscription.cancel()
  }

  @Test(
    "Default Observes When Status For Context Value",
    arguments: [
      (NetworkConnectionStatus.disconnected, false),
      (.connected, true),
      (.requiresConnection, true)
    ]
  )
  func observesWhenStatusForContextValue(status: NetworkConnectionStatus, isSatisfied: Bool) {
    var context = OperationContext()
    context.satisfiedConnectionStatus = .requiresConnection

    let satisfactions = RecursiveLock([Bool]())
    let observer = MockNetworkObserver()
    let c: some OperationRunSpecification = .connected(to: observer)
    let subscription = c.subscribe(in: context) { satisfied in
      satisfactions.withLock { $0.append(satisfied) }
    }
    observer.send(status: status)
    satisfactions.withLock { expectNoDifference($0, [true, isSatisfied]) }
    subscription.cancel()
  }
}
