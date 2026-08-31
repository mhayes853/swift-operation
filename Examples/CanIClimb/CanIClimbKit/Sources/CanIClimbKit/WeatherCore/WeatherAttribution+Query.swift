import Dependencies
import Operation
import WeatherKit

// MARK: - Query

extension WeatherAttribution {
  @QueryRequest
  public static func currentQuery() async throws -> WeatherAttribution {
    @Dependency(WeatherForecasterKey.self) var weather
    return try await weather.attribution
  }
}
