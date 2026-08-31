import Dependencies
import Operation
import WeatherKit

// MARK: - WeatherForecaster

public protocol WeatherForecaster: Sendable {
  func reading(for coordinate: LocationCoordinate2D) async throws -> WeatherReading
  var attribution: WeatherAttribution { get async throws }
}

public enum WeatherForecasterKey: DependencyKey {
  public static var liveValue: any WeatherForecaster {
    WeatherService.shared
  }
}

@MainActor
public final class MockWeatherForecaster: WeatherForecaster {
  public var readingResults = [LocationCoordinate2D: Result<WeatherReading, any Error>]()
  public var defaultReading: WeatherReading?
  public var attributionResult: Result<WeatherAttribution, any Error>?

  public init() {}

  public func reading(for coordinate: LocationCoordinate2D) async throws -> WeatherReading {
    if let result = self.readingResults[coordinate] {
      return try result.get()
    }
    guard let defaultReading = self.defaultReading else { throw MissingResultError() }
    return defaultReading
  }

  public var attribution: WeatherAttribution {
    get async throws {
      guard let result = self.attributionResult else { throw MissingResultError() }
      return try result.get()
    }
  }

  private struct MissingResultError: Error {}
}

// MARK: - Query

extension WeatherReading {
  @QueryRequest
  public static func currentQuery(
    for coordinate: LocationCoordinate2D
  ) async throws -> WeatherReading {
    @Dependency(WeatherForecasterKey.self) var weather
    return try await weather.reading(for: coordinate)
  }
}
