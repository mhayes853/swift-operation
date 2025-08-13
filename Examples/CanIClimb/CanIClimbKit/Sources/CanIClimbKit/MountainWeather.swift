import Dependencies
import Observation
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - MountainWeatherModel

@MainActor
@Observable
public final class MountainWeatherModel {
  @ObservationIgnored
  @SharedQuery<WeatherReading.CurrentQuery.State> private var mountainWeather: WeatherReading?

  public var destination: Destination?
  public let mountain: Mountain

  private var userWeather: SharedQuery<WeatherReading.CurrentQuery.State>?
  private var userLocation: Result<LocationReading, any Error>?

  public var isUserLocationAuthorized: Bool {
    switch self.userLocation {
    case .failure(let error): error is UserLocationUnauthorizedError
    default: true
    }
  }

  public init(mountain: Mountain) {
    self.mountain = mountain
    self._mountainWeather = SharedQuery(
      WeatherReading.currentQuery(for: mountain.location.coordinate),
      animation: .bouncy
    )
  }

  public func userLocationUpdated(reading: Result<LocationReading, any Error>) {
    self.userLocation = reading
    self.userWeather = (try? reading.get())
      .map { SharedQuery(WeatherReading.currentQuery(for: $0.coordinate), animation: .bouncy) }
  }
}

extension MountainWeatherModel {
  public struct Detail: Equatable, Sendable {
    public let locationName: LocalizedStringResource
    @SharedQuery<WeatherReading.CurrentQuery.State> public var reading: WeatherReading?
  }

  public var userWeatherDetail: Detail? {
    self.userWeather.map { Detail(locationName: "Your Location", reading: $0) }
  }

  public var mountainWeatherDetail: Detail {
    Detail(
      locationName: self.mountain.location.name.localizedStringResource,
      reading: self.$mountainWeather
    )
  }
}

extension MountainWeatherModel {
  @CasePathable
  public enum Destination: Equatable, Sendable {
    case detail(Detail)
  }

  public func detailInvoked(_ detail: Detail) {
    self.destination = .detail(detail)
  }
}

// MARK: - MountainWeatherView

public struct MountainWeatherView: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  @Bindable private var model: MountainWeatherModel

  public init(model: MountainWeatherModel) {
    self.model = model
  }

  public var body: some View {
    HStack {
      Text("Mountain Name: \(model.mountain.name)")
    }
  }
}

#Preview {
  let userLocation = LocationReading.mock()
  let _ = prepareDependencies {
    let weather = WeatherReading.MockCurrentReader()
    weather.results[userLocation.coordinate] = .success(.mock(location: userLocation))
    weather.results[Mountain.mock1.location.coordinate] = .success(
      .mock(location: .mock(coordinate: Mountain.mock1.location.coordinate))
    )
    $0[WeatherReading.CurrentReaderKey.self] = weather
  }

  let model = MountainWeatherModel(mountain: Mountain.mock1)
  let _ = model.userLocationUpdated(reading: .success(userLocation))

  MountainWeatherView(model: model)
}
