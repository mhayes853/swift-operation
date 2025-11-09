import MacroTesting
import OperationMacros
import SnapshotTesting
import Testing

@MainActor
@Suite(
  .serialized,
  .macros(
    ["ContextEntry": ContextEntryMacro.self],
    record: .failed
  )
) struct BaseTestSuite {}
