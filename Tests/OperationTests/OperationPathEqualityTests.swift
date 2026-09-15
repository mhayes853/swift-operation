import CustomDump
import Operation
import Testing

@Suite
struct `OperationPath Equality tests` {
  @Test
  func `Single Element Does Not Equal A Longer Path`() {
    let single = OperationPath("users")
    let longer = OperationPath(["users", "current"])

    expectNoDifference(single == longer, false)
    expectNoDifference(longer == single, false)
    expectNoDifference(Set([single, OperationPath(["users"]), longer]).count, 2)
  }
}
