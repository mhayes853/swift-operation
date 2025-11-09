import MacroTesting
import OperationMacros
import SnapshotTesting
import Testing

@MainActor
@Suite(
  .serialized,
  .macros(
    [
      "ContextEntry": ContextEntryMacro.self,
      "OperationRequest": OperationRequestMacro.self,
      "QueryRequest": QueryRequestMacro.self
    ],
    record: .failed
  )
) struct BaseTestSuite {}
