import Observation
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - MountainWeatherModel

@MainActor
@Observable
public final class MountainWeatherModel {
  @ObservationIgnored
  @SharedQuery<WeatherReading.CurrentQuery.State> public var mountainWeather: WeatherReading?

  public var destination: Destination?

  public private(set) var userWeather: SharedQuery<WeatherReading.CurrentQuery.State>?
  public private(set) var userLocation: Result<LocationReading, any Error>?
  public let mountain: Mountain

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

  @CasePathable
  public enum Destination: Equatable, Sendable {
    case detail(Detail)
  }

  public func userWeatherInvoked() {
    guard let userWeather else { return }
    self.destination = .detail(Detail(locationName: "Your Location", reading: userWeather))
  }

  public func mountainWeatherInvoked() {
    self.destination = .detail(
      Detail(
        locationName: self.mountain.location.name.localizedStringResource,
        reading: self.$mountainWeather
      )
    )
  }
}

// MARK: - MountainWeatherView

public struct MountainWeatherView: View {
  @Bindable private var model: MountainWeatherModel

  public init(model: MountainWeatherModel) {
    self.model = model
  }

  public var body: some View {
    VStack {
      Text("Mountain Name: \(model.mountain.name)")
    }
  }
}
