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
      let url = "https://en.wikipedia.org/api/rest_v1/page/summary/\(number)"
      let response = try await JSPromise(JSObject.global.fetch!(url).object!)!.value
      guard response.ok.boolean == true else { throw LoadingError(number: number) }
      let json = try await JSPromise(response.json().object!)!.value
      guard let content = json.extract.string else { throw LoadingError(number: number) }
      return NumberFact(number: number, content: content)
    }
  }

  public struct LoadingError: Error, Hashable, Sendable {
    public let number: Int

    public init(number: Int) {
      self.number = number
    }
  }
}

// MARK: - Query

extension NumberFact {
  public static func query(for number: Int) -> some QueryRequest<Self, any Error> {
    Self.$query(for: number).taskConfiguration { $0.name = "Fetch number fact for \(number)" }
  }

  @QueryRequest
  private static func query(for number: Int) async throws -> NumberFact {
    @Dependency(NumberFact.LoaderKey.self) var loader
    return try await loader.fact(for: number)
  }
}
