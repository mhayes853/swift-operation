import Query
import WeatherKit

extension WeatherAttribution {
  public static let currentQuery = CurrentQuery().staleWhenNoValue()

  public struct CurrentQuery: QueryRequest, Hashable {
    public func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<WeatherAttribution>
    ) async throws -> WeatherAttribution {
      try await WeatherService.shared.attribution
    }
  }
}
