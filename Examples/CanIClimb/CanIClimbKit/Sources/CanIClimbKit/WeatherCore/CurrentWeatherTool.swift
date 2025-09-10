import FoundationModels
import Operation

public struct CurrentWeatherTool: Tool {
  public let name = "Current Weather"
  public let description = "Provides the current weather conditions for a lat-lng coordinate"

  @Generable
  public struct Arguments: Hashable, Sendable {
    public let coordinate: LocationCoordinate2D.Generable
  }

  private let client: OperationClient

  public init(client: OperationClient) {
    self.client = client
  }

  public func call(arguments: Arguments) async throws -> WeatherReading.Generable {
    let coordinate = LocationCoordinate2D(generable: arguments.coordinate)
    let store = client.store(for: WeatherReading.currentQuery(for: coordinate))
    return WeatherReading.Generable(reading: try await store.fetch())
  }
}
