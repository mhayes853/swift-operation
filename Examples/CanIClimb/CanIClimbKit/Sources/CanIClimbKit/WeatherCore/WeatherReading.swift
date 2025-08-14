import Foundation
import WeatherKit

// MARK: - WeatherReading

public struct WeatherReading: Hashable, Sendable {
  public typealias Condition = WeatherCondition

  public var location: LocationReading
  public var systemImageName: String
  public var condition: Condition
  public var humidity: Double
  public var temperature: Measurement<UnitTemperature>
  public var feelsLikeTemperature: Measurement<UnitTemperature>
  public var visibility: Measurement<UnitLength>
  public var wind: Wind
  public var cloudCover: CloudCover
  public var precipitationIntensity: Measurement<UnitSpeed>
  public var pressure: Pressure
  public var uvIndex: UVIndex

  public init(
    location: LocationReading,
    systemImageName: String,
    condition: WeatherReading.Condition,
    humidity: Double,
    temperature: Measurement<UnitTemperature>,
    feelsLikeTemperature: Measurement<UnitTemperature>,
    visibility: Measurement<UnitLength>,
    wind: Wind,
    cloudCover: CloudCover,
    precipitationIntensity: Measurement<UnitSpeed>,
    pressure: Pressure,
    uvIndex: UVIndex
  ) {
    self.location = location
    self.systemImageName = systemImageName
    self.condition = condition
    self.humidity = humidity
    self.temperature = temperature
    self.feelsLikeTemperature = feelsLikeTemperature
    self.visibility = visibility
    self.wind = wind
    self.cloudCover = cloudCover
    self.precipitationIntensity = precipitationIntensity
    self.pressure = pressure
    self.uvIndex = uvIndex
  }
}

// MARK: - Wind

extension WeatherReading {
  public struct Wind: Hashable, Sendable {
    public typealias CompassDirection = WeatherKit.Wind.CompassDirection

    public var direction: CompassDirection
    public var speed: Measurement<UnitSpeed>

    public init(direction: CompassDirection, speed: Measurement<UnitSpeed>) {
      self.direction = direction
      self.speed = speed
    }
  }
}

// MARK: - CloudCover

extension WeatherReading {
  public struct CloudCover: Hashable, Sendable {
    public var lowAltitude: Double
    public var midAltitude: Double
    public var highAltitude: Double

    public init(lowAltitude: Double, midAltitude: Double, highAltitude: Double) {
      self.lowAltitude = lowAltitude
      self.midAltitude = midAltitude
      self.highAltitude = highAltitude
    }
  }
}

// MARK: - Pressure

extension WeatherReading {
  public struct Pressure: Hashable, Sendable {
    public typealias Trend = WeatherKit.PressureTrend

    public var amount: Measurement<UnitPressure>
    public var trend: Trend

    public init(amount: Measurement<UnitPressure>, trend: Trend) {
      self.amount = amount
      self.trend = trend
    }
  }
}

// MARK: - UVIndex

extension WeatherReading {
  public struct UVIndex: Hashable, Sendable {
    public typealias ExposureCategory = WeatherKit.UVIndex.ExposureCategory

    public var amount: Int
    public var exposureCategory: ExposureCategory

    public init(amount: Int, exposureCategory: ExposureCategory) {
      self.amount = amount
      self.exposureCategory = exposureCategory
    }
  }
}

// MARK: - Mocks

extension WeatherReading {
  public static func mock(
    location: LocationReading = LocationReading(
      coordinate: .alcatraz,
      altitudeAboveSeaLevel: Measurement(value: 0, unit: .meters)
    ),
    systemImageName: String = "sun.max",
    condition: Condition = .clear,
    humidity: Double = 0.5,
    temperature: Measurement<UnitTemperature> = Measurement(value: 20, unit: .celsius),
    feelsLikeTemperature: Measurement<UnitTemperature> = Measurement(value: 20, unit: .celsius),
    visibility: Measurement<UnitLength> = Measurement(value: 10, unit: .kilometers),
    wind: Wind = Wind(direction: .north, speed: Measurement(value: 10, unit: .kilometersPerHour)),
    cloudCover: CloudCover = CloudCover(lowAltitude: 0, midAltitude: 0, highAltitude: 0),
    precipitationIntensity: Measurement<UnitSpeed> = Measurement(value: 0, unit: .metersPerSecond),
    pressure: Pressure = Pressure(
      amount: Measurement(value: 1013, unit: .hectopascals),
      trend: .steady
    ),
    uvIndex: UVIndex = UVIndex(amount: 0, exposureCategory: .low)
  ) -> Self {
    Self(
      location: location,
      systemImageName: systemImageName,
      condition: condition,
      humidity: humidity,
      temperature: temperature,
      feelsLikeTemperature: feelsLikeTemperature,
      visibility: visibility,
      wind: wind,
      cloudCover: cloudCover,
      precipitationIntensity: precipitationIntensity,
      pressure: pressure,
      uvIndex: uvIndex
    )
  }
}
