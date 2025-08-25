import CustomDump
import Dependencies
import SharingOperation
import Testing

@Suite("NetworkStatusKey tests")
struct NetworkStatusKeyTests {
  @Test("Observes Changes From The Network")
  func observesChanges() {
    let observer = MockNetworkObserver()
    withDependencies {
      $0.defaultNetworkObserver = observer
    } operation: {
      @SharedReader(.networkStatus) var status = .connected

      expectNoDifference(status, .connected)

      observer.send(status: .disconnected)
      expectNoDifference(status, .disconnected)

      observer.send(status: .requiresConnection)
      expectNoDifference(status, .requiresConnection)

      observer.send(status: .connected)
      expectNoDifference(status, .connected)
    }
  }
}
