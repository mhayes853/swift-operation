import CoreLocation
import WeatherKit

// MARK: - Conversions

extension WeatherReading {
  public init(currentWeather: CurrentWeather) {
    self.init(
      location: LocationReading(location: currentWeather.metadata.location),
      systemImageName: currentWeather.symbolName,
      condition: currentWeather.condition,
      humidity: currentWeather.humidity,
      temperature: currentWeather.temperature,
      feelsLikeTemperature: currentWeather.apparentTemperature,
      visibility: currentWeather.visibility,
      wind: Wind(wind: currentWeather.wind),
      cloudCover: CloudCover(cloudCoverByAltitude: currentWeather.cloudCoverByAltitude)
    )
  }
}

extension WeatherReading.Wind {
  public init(wind: WeatherKit.Wind) {
    self.init(direction: wind.compassDirection, speed: wind.speed)
  }
}

extension WeatherReading.CloudCover {
  public init(cloudCoverByAltitude: CloudCoverByAltitude) {
    self.init(
      lowAltitude: cloudCoverByAltitude.low,
      midAltitude: cloudCoverByAltitude.medium,
      highAltitude: cloudCoverByAltitude.high
    )
  }
}

// MARK: - CurrentReader

extension WeatherService: WeatherReading.CurrentReader {
  public func reading(for coordinate: LocationCoordinate2D) async throws -> WeatherReading {
    let location = CLLocation(coordinate: coordinate)
    let weather = try await self.weather(for: location, including: .current)
    return WeatherReading(currentWeather: weather)
  }
}
