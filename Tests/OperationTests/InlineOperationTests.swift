import CustomDump
import Operation
import Testing

@Suite("InlineOperation tests")
struct InlineOperationTests {
  @Test("Returns The Value From The Closure")
  func returnsTheValueFromTheClosure() async {
    let value = await #run(InlineOperation { _ in 42 })
    expectNoDifference(value, 42)
  }

  @Test("Rethrows The Error From The Closure")
  func rethrowsTheErrorFromTheClosure() async {
    let operation = InlineOperation<Int, any Error> { _ in throw SomeError() }
    await #expect(throws: SomeError.self) { try await #run(operation) }
  }

  @Test("Reads Values From The Context It Is Run In")
  func readsValuesFromTheContextItIsRunIn() async {
    var context = OperationContext()
    context.operationMaxRetries = 7
    let value = await #run(InlineOperation { $0.operationMaxRetries }, context: context)
    expectNoDifference(value, 7)
  }

  @Test("Yields Values Through The Continuation")
  func yieldsValuesThroughTheContinuation() async throws {
    let yielded = RecursiveLock([Int]())
    let operation = InlineOperation<Int, any Error> { _, continuation in
      continuation.yield(1)
      continuation.yield(2)
      return 3
    }
    let value = try await #run(
      operation,
      context: OperationContext(),
      continuation: OperationContinuation { result, _ in
        guard case .success(let next) = result else { return }
        yielded.withLock { $0.append(next) }
      }
    )
    expectNoDifference(value, 3)
    expectNoDifference(yielded.withLock { $0 }, [1, 2])
  }

  @Test("Uses The Provided Debug Name")
  func usesTheProvidedDebugName() {
    let operation = InlineOperation("server readiness") { _ in true }
    expectNoDifference(operation._debugTypeName, "server readiness")
  }

  @Test("Falls Back To The Type Name Without A Debug Name")
  func fallsBackToTheTypeNameWithoutADebugName() {
    let operation = InlineOperation { _ in true }
    expectNoDifference(operation._debugTypeName.hasPrefix("InlineOperation"), true)
  }
}

private struct SomeError: Equatable, Error {}
