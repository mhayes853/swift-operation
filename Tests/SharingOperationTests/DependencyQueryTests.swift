import CustomDump
import Dependencies
import SharingOperation
import Testing

@Suite("DependencyQuery tests")
struct DependencyQueryTests {
  private let client = OperationClient()

  @Test("Propogates Dependency To Query")
  func propogatesDependencyToQuery() async throws {
    let store = self.client.store(for: DependencyQuery())
    try await withDependencies {
      $0[NumberKey.self] = 10
    } operation: {
      let value = try await store.fetch()
      expectNoDifference(value, 10)
    }
  }
}

private struct DependencyQuery: QueryRequest {
  @Dependency(NumberKey.self) var number

  var path: OperationPath {
    ["dependency", self.number]
  }

  func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Int, any Error>
  ) async throws -> Int {
    self.number
  }
}

private enum NumberKey: TestDependencyKey {
  static var testValue: Int { 0 }
}
