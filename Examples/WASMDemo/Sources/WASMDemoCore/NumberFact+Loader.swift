import JavaScriptEventLoop
@preconcurrency import JavaScriptKit

// MARK: - Loader

extension NumberFact {
  public protocol Loader: Sendable {
    func fact(for number: Int) async throws -> NumberFact
  }
}

// MARK: - APILoader

extension NumberFact {
  public struct APILoader: Loader {
    public init() {}

    public func fact(for number: Int) async throws -> NumberFact {
      // NB: Add a bit of fake delay to exemplify loading.
      try await Task.sleep(for: .seconds(0.3))
      let response = try await JSPromise(
        JSObject.global.fetch!("http://www.numberapi.com/\(number)").object!
      )!
      .value
      let content = try await JSPromise(response.text().object!)!.value.string!
      return NumberFact(number: number, content: content)
    }
  }
}
