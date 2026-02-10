import CustomDump
import Foundation
import Operation
import Testing

@Suite("Run macro tests")
struct RunMacroTests {
  @Test("Runs With Defaults")
  func runsWithDefaults() async {
    let value = await #run($runMacroOperation)
    expectNoDifference(value, 42)
  }

  @Test("Uses Provided Context")
  func usesProvidedContext() async {
    var context = OperationContext()
    context.multiplier = 3

    let value = await #run($runMacroContextOperation(input: 4), context: context)
    expectNoDifference(value, 12)
  }

  @Test("Runs Setup Through OperationRunner")
  func runsSetupThroughOperationRunner() async {
    let value = await #run(SetupAwareOperation())
    expectNoDifference(value, 7)
  }

  @Test("Uses Provided Continuation")
  func usesProvidedContinuation() async {
    let results = LockedBox<[Int]>([])
    let continuation = OperationContinuation<Int, Never> { result, _ in
      guard case let .success(value) = result else { return }
      results.withLock { $0.append(value) }
    }

    let value = await #run(
      $runMacroContinuationOperation,
      context: OperationContext(),
      continuation: continuation
    )

    expectNoDifference(value, 42)
    expectNoDifference(results.value, [1, 2])
  }
}

@OperationRequest
private func runMacroOperation() -> Int {
  42
}

@OperationRequest
private func runMacroContextOperation(input: Int, context: OperationContext) -> Int {
  input * context.multiplier
}

@OperationRequest
private func runMacroContinuationOperation(continuation: OperationContinuation<Int, Never>) -> Int {
  continuation.yield(1)
  continuation.yield(2)
  return 42
}

private struct SetupAwareOperation: OperationRequest {
  func setup(context: inout OperationContext) {
    context.setupValue = 7
  }

  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Int, Never>
  ) async -> Int {
    context.setupValue
  }
}

extension OperationContext {
  @ContextEntry fileprivate var multiplier = 1
  @ContextEntry fileprivate var setupValue = 0
}

private final class LockedBox<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: Value

  init(_ value: Value) {
    self._value = value
  }

  var value: Value {
    self.withLock { $0 }
  }

  func withLock<R>(_ body: (inout Value) -> R) -> R {
    self.lock.lock()
    defer { self.lock.unlock() }
    return body(&self._value)
  }
}
