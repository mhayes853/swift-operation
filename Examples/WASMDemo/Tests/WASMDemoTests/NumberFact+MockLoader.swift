import WASMDemoCore

extension NumberFact {
  @MainActor
  final class MockLoader: NumberFact.Loader {
    var contents = [Int: String]()

    func fact(for number: Int) async throws -> NumberFact {
      guard let content = self.contents[number] else { throw NoFactError() }
      return NumberFact(number: number, content: content)
    }
  }
}

private struct NoFactError: Error {}
