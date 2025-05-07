#if canImport(Dispatch)
  import Query
  import Testing
  import CustomDump
  import Dispatch

  @Suite("MemoryPressure tests")
  struct MemoryPressureTests {
    @Test("Is Equivalent To Dispatch Pressure")
    func dispatchEquivalent() {
      let args = [
        (DispatchSource.MemoryPressureEvent.all, MemoryPressure.all),
        (.warning, .warning),
        ([.normal, .critical], [.normal, .critical])
      ]
      for (d, expected) in args {
        expectNoDifference(MemoryPressure(from: d), expected)
      }
    }
  }
#endif
