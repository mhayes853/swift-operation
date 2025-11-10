import FoundationModels
import Operation

public struct CurrentWeatherTool: Tool {
  public let name = "currentWeather"
  public let description =
    "Provides the current weather conditions for a latitude - longitude coordinate."

  @Generable
  public struct Arguments: Hashable, Sendable {
    public let coordinate: LocationCoordinate2DGenerable
  }

  private let client: OperationClient

  public init(client: OperationClient) {
    self.client = client
  }

  public func call(arguments: Arguments) async throws -> WeatherReadingGenerable {
    let coordinate = LocationCoordinate2D(generable: arguments.coordinate)
    let store = client.store(for: WeatherReading.currentQuery(for: coordinate))
    return WeatherReadingGenerable(reading: try await store.fetch())
  }
}
