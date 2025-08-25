import Dependencies
import JavaScriptEventLoop
@preconcurrency import JavaScriptKit
import Operation

// MARK: - Loader

extension NumberFact {
  public protocol Loader: Sendable {
    func fact(for number: Int) async throws -> NumberFact
  }

  public enum LoaderKey: DependencyKey {
    public static let liveValue: any Loader = NumberFact.APILoader()
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

// MARK: - Query

extension NumberFact {
  public static func query(for number: Int) -> some QueryRequest<Self, Query.State> {
    Query(number: number).taskConfiguration { $0.name = "Fetch number fact for \(number)" }
  }

  public struct Query: QueryRequest, Hashable {
    let number: Int

    public func fetch(
      in context: OperationContext,
      with continuation: OperationContinuation<NumberFact>
    ) async throws -> NumberFact {
      @Dependency(NumberFact.LoaderKey.self) var loader
      return try await loader.fact(for: self.number)
    }
  }
}
