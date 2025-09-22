#if canImport(Combine)
  import Operation
  import Combine
  import Testing
  import CustomDump
  import OperationTestHelpers

  @Suite("OperationStore+Publisher tests")
  struct OperationStorePublisherTests {
    private let client = OperationClient()

    @Test("Emits State Updates From Publisher")
    func emitsStateUpdatesFromPublisher() async throws {
      let store = self.client.store(for: TestQuery())
      let states = Lock([TestQuery.State]())
      let cancellable = store.publisher.sink { output in
        states.withLock { $0.append(output.state) }
      }
      _ = try? await store.activeTasks.first?.runIfNeeded()
      states.withLock {
        expectNoDifference($0.count, 3)
        expectNoDifference($0[0].status.isIdle, true)
        expectNoDifference($0[1].isLoading, true)
        expectNoDifference($0[2].currentValue, TestQuery.value)
      }
      cancellable.cancel()
    }
  }
#endif
