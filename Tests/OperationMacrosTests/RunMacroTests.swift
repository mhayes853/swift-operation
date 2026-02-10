import MacroTesting
import OperationMacros
import Testing

extension BaseTestSuite {
  @Suite("RunMacro tests")
  struct RunMacroTests {
    @Test("Run With Defaults")
    func runWithDefaults() {
      assertMacro {
        """
        func run(operation: some OperationRequest<Int, Never>) async {
          _ = await #run(operation)
        }
        """
      } expansion: {
        """
        func run(operation: some OperationRequest<Int, Never>) async {
          _ = await OperationCore.OperationRunner(
            operation: operation,
            initialContext: OperationCore.OperationContext()
          ).run(with: OperationCore.OperationContinuation { _, _ in
            })
        }
        """
      }
    }

    @Test("Run With Context")
    func runWithContext() {
      assertMacro {
        """
        func run(operation: some OperationRequest<Int, Never>, context: OperationContext) async {
          _ = await #run(operation, context: context)
        }
        """
      } expansion: {
        """
        func run(operation: some OperationRequest<Int, Never>, context: OperationContext) async {
          _ = await OperationCore.OperationRunner(
            operation: operation,
            initialContext: context
          ).run(with: OperationCore.OperationContinuation { _, _ in
            })
        }
        """
      }
    }

    @Test("Run With Context And Continuation")
    func runWithContextAndContinuation() {
      assertMacro {
        """
        func run(
          operation: some OperationRequest<Int, Never>,
          context: OperationContext,
          continuation: OperationContinuation<Int, Never>
        ) async {
          _ = await #run(operation, context: context, continuation: continuation)
        }
        """
      } expansion: {
        """
        func run(
          operation: some OperationRequest<Int, Never>,
          context: OperationContext,
          continuation: OperationContinuation<Int, Never>
        ) async {
          _ = await OperationCore.OperationRunner(
            operation: operation,
            initialContext: context
          ).run(with: continuation)
        }
        """
      }
    }
  }
}
