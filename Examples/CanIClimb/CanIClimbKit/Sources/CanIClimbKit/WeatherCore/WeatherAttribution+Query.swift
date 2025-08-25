import Dependencies
import Operation
import WeatherKit

// MARK: - Loader

extension WeatherAttribution {
  public protocol Loader: Sendable {
    var attribution: WeatherAttribution { get async throws }
  }

  public enum LoaderKey: DependencyKey {
    public static let liveValue: any Loader = WeatherService.shared
  }
}

extension WeatherService: WeatherAttribution.Loader {}

// MARK: - Query

extension WeatherAttribution {
  public static let currentQuery = CurrentQuery().staleWhenNoValue()

  public struct CurrentQuery: QueryRequest, Hashable {
    public func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<WeatherAttribution>
    ) async throws -> WeatherAttribution {
      @Dependency(WeatherAttribution.LoaderKey.self) var loader
      return try await loader.attribution
    }
  }
}
