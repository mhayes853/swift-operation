import FoundationModels

@Generable
public struct WeatherReadingGenerable: Hashable, Sendable {
  public var condition: String
  public var humidity: Double
  public var temperatureCelsius: Double
  public var feelsLikeTemperatureCelsius: Double
  public var visibilityMeters: Double
  public var windDirection: String
  public var windSpeedKMPH: Double
  public var cloudCoverLowAltitude: Double
  public var cloudCoverMidAltitude: Double
  public var cloudCoverHighAltitude: Double
  public var precipitationIntensityKMPH: Double
  public var pressureAmountKilopascals: Double
  public var pressureTrend: String
  public var uvIndexAmount: Int
  public var uvIndexExposureCategory: String

  public init(
    condition: String,
    humidity: Double,
    temperatureCelsius: Double,
    feelsLikeTemperatureCelsius: Double,
    visibilityMeters: Double,
    windDirection: String,
    windSpeedKMPH: Double,
    cloudCoverLowAltitude: Double,
    cloudCoverMidAltitude: Double,
    cloudCoverHighAltitude: Double,
    precipitationIntensityKMPH: Double,
    pressureAmountKilopascals: Double,
    pressureTrend: String,
    uvIndexAmount: Int,
    uvIndexExposureCategory: String
  ) {
    self.condition = condition
    self.humidity = humidity
    self.temperatureCelsius = temperatureCelsius
    self.feelsLikeTemperatureCelsius = feelsLikeTemperatureCelsius
    self.visibilityMeters = visibilityMeters
    self.windDirection = windDirection
    self.windSpeedKMPH = windSpeedKMPH
    self.cloudCoverLowAltitude = cloudCoverLowAltitude
    self.cloudCoverMidAltitude = cloudCoverMidAltitude
    self.cloudCoverHighAltitude = cloudCoverHighAltitude
    self.precipitationIntensityKMPH = precipitationIntensityKMPH
    self.pressureAmountKilopascals = pressureAmountKilopascals
    self.pressureTrend = pressureTrend
    self.uvIndexAmount = uvIndexAmount
    self.uvIndexExposureCategory = uvIndexExposureCategory
  }
}

extension WeatherReadingGenerable {
  public init(reading: WeatherReading) {
    self.init(
      condition: reading.condition.description,
      humidity: reading.humidity,
      temperatureCelsius: reading.temperature.converted(to: .celsius).value,
      feelsLikeTemperatureCelsius: reading.feelsLikeTemperature.converted(to: .celsius).value,
      visibilityMeters: reading.visibility.converted(to: .meters).value,
      windDirection: reading.wind.direction.description,
      windSpeedKMPH: reading.wind.speed.converted(to: .kilometersPerHour).value,
      cloudCoverLowAltitude: reading.cloudCover.lowAltitude,
      cloudCoverMidAltitude: reading.cloudCover.midAltitude,
      cloudCoverHighAltitude: reading.cloudCover.highAltitude,
      precipitationIntensityKMPH: reading.precipitationIntensity.converted(to: .kilometersPerHour)
        .value,
      pressureAmountKilopascals: reading.pressure.amount.converted(to: .kilopascals).value,
      pressureTrend: reading.pressure.trend.description,
      uvIndexAmount: reading.uvIndex.amount,
      uvIndexExposureCategory: reading.uvIndex.exposureCategory.description
    )
  }
}
