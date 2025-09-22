#if canImport(Darwin)
  import Operation
  import Testing
  import CustomDump
  import Dispatch

  @Suite("MemoryPressure tests")
  struct MemoryPressureTests {
    @Test("Is Equivalent To Dispatch Pressure")
    func dispatchEquivalent() {
      // NB: - Cannot use parameterized tests due to dispatch event not being Sendable.
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
