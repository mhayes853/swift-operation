import Dependencies
import Operation
import WeatherKit

// MARK: - CurrentReader

extension WeatherReading {
  public protocol CurrentReader: Sendable {
    func reading(for coordinate: LocationCoordinate2D) async throws -> WeatherReading
  }

  public enum CurrentReaderKey: DependencyKey {
    public static let liveValue: any CurrentReader = WeatherService.shared
  }
}

extension WeatherReading {
  @MainActor
  public final class MockCurrentReader: CurrentReader {
    public var results = [LocationCoordinate2D: Result<WeatherReading, Error>]()

    public init() {}

    public func reading(for coordinate: LocationCoordinate2D) async throws -> WeatherReading {
      guard let result = self.results[coordinate] else { throw NoReadingError() }
      return try result.get()
    }

    private struct NoReadingError: Error {}
  }
}

extension WeatherReading {
  public struct SucceedingCurrentReader: CurrentReader {
    public init() {}

    public func reading(for coordinate: LocationCoordinate2D) async throws -> WeatherReading {
      .mock()
    }
  }
}

// MARK: - Query

extension WeatherReading {
  public static func currentQuery(
    for coordinate: LocationCoordinate2D
  ) -> some QueryRequest<Self, any Error> {
    CurrentQuery(coordinate: coordinate)
  }

  public struct CurrentQuery: QueryRequest, Hashable {
    let coordinate: LocationCoordinate2D

    public func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<WeatherReading, any Error>
    ) async throws -> WeatherReading {
      @Dependency(WeatherReading.CurrentReaderKey.self) var reader
      return try await reader.reading(for: coordinate)
    }
  }
}
