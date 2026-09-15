import CustomDump
import Operation
import OperationTestHelpers
import Testing

@Suite("PaginatedStore Task Name tests")
struct PaginatedStoreTaskNameTests {
  @Test
  func `Preserves A Custom Refetch All Pages Task Name`() {
    let store = OperationClient().store(for: TestPaginated())
    var context = OperationContext()
    context.operationTaskConfiguration.name = "Custom Task"

    let task = store.refetchAllPagesTask(using: context)

    expectNoDifference(task.configuration.name, "Custom Task")
  }
}
