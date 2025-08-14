import Dependencies
import Observation
import SharingGRDB
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - MountainWeatherModel

@MainActor
@Observable
public final class MountainWeatherModel {
  @ObservationIgnored
  @SharedQuery<WeatherReading.CurrentQuery.State> private var mountainWeather: WeatherReading?

  @ObservationIgnored
  @Fetch(wrappedValue: SettingsRecord(), .singleRow(SettingsRecord.self)) private var settings

  public var destination: Destination?
  public let mountain: Mountain

  public var temperaturePreference: SettingsRecord.TemperaturePreference {
    self.settings.temperaturePreference
  }

  private var userWeather: SharedQuery<WeatherReading.CurrentQuery.State>?
  private var userLocation: Result<LocationReading, any Error>?

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
  public struct Detail: Equatable, Sendable, Identifiable {
    public enum ID: Hashable, Sendable {
      case user
      case mountain(Mountain.ID)
    }

    public let id: ID
    public let systemImageName: String
    public let locationName: LocalizedStringResource
    public let unauthorizedText: LocalizedStringResource?
    public var reading: SharedQuery<WeatherReading.CurrentQuery.State>?
  }

  public var userWeatherDetail: Detail {
    let isAuthorized =
      switch self.userLocation {
      case .failure(let error): !(error is UserLocationUnauthorizedError)
      default: true
      }
    return Detail(
      id: .user,
      systemImageName: "location.fill",
      locationName: "Your Location",
      unauthorizedText: isAuthorized ? nil : "Your location access has been denied.",
      reading: self.userWeather
    )
  }

  public var mountainWeatherDetail: Detail {
    Detail(
      id: .mountain(self.mountain.id),
      systemImageName: "mappin.and.ellipse",
      locationName: self.mountain.location.name.localizedStringResource,
      unauthorizedText: nil,
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
    Group {
      if self.dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading) {
          WeatherSnippetView(model: model, detail: model.userWeatherDetail)
          Divider()
          WeatherSnippetView(model: model, detail: model.mountainWeatherDetail)
          WeatherAttributionView()
        }
      } else {
        VStack {
          HStack(alignment: .center) {
            WeatherSnippetView(model: model, detail: model.userWeatherDetail)
            Divider()
              .padding(.horizontal)
            WeatherSnippetView(model: model, detail: model.mountainWeatherDetail)
          }
          WeatherAttributionView()
        }
      }
    }
    .sheet(item: self.$model.destination.detail) { detail in
      NavigationStack {
        WeatherDetailView(detail: detail, temperaturePreference: self.model.temperaturePreference)
          .dismissable()
      }
    }
  }
}

// MARK: - WeatherSnippetView

private struct WeatherSnippetView: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  let model: MountainWeatherModel
  let detail: MountainWeatherModel.Detail

  var body: some View {
    let details = VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .center) {
        Image(systemName: self.detail.systemImageName)
        Text(self.detail.locationName)
      }
      .foregroundStyle(.secondary)

      if let unauthorizedText = self.detail.unauthorizedText {
        Text(unauthorizedText)
      } else {
        switch self.detail.reading?.status {
        case .result(.success(let weather)):
          VStack(alignment: .leading) {
            HStack(alignment: .center) {
              Image(systemName: weather.systemImageName)
              Text(weather.temperature.formatted(preference: self.model.temperaturePreference))
            }
            .font(.title3.bold())
            Group {
              Text(weather.condition.description)
              let feelsLike = weather.feelsLikeTemperature
                .formatted(preference: self.model.temperaturePreference)
              Text("Feels Like: \(feelsLike)")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
          }
        case .result(.failure):
          Text("--")
            .foregroundStyle(.secondary)

        default:
          SpinnerView()
        }
      }
    }

    Button {
      self.model.detailInvoked(self.detail)
    } label: {
      if self.dynamicTypeSize.isAccessibilitySize {
        HStack(alignment: .center) {
          details
          Spacer()
          Image(systemName: "chevron.right")
        }
      } else {
        details
      }
    }
    .buttonStyle(.plain)
  }
}

// MARK: - WeatherDetailView

private struct WeatherDetailView: View {
  let detail: MountainWeatherModel.Detail
  let temperaturePreference: SettingsRecord.TemperaturePreference

  var body: some View {
    Form {
      if let unauthorizedText = self.detail.unauthorizedText {
        Text(unauthorizedText)
      } else if let reading = self.detail.reading {
        RemoteQueryStateView(reading) { weather in
          WeatherReadingFormView(
            weather: weather,
            temperaturePreference: self.temperaturePreference
          )
          Section {
            HStack {
              Spacer()
              WeatherAttributionView()
              Spacer()
            }
          }
        }
      } else {
        SpinnerView()
      }
    }
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .principal) {
        HStack(alignment: .center) {
          Image(systemName: self.detail.systemImageName)
          Text(self.detail.locationName)
        }
      }
    }
  }
}

// MARK: - WeatherReadingFormView

private struct WeatherReadingFormView: View {
  let weather: WeatherReading
  let temperaturePreference: SettingsRecord.TemperaturePreference

  var body: some View {
    Section {
      HStack {
        Spacer()
        VStack(alignment: .leading) {
          HStack(alignment: .center) {
            Image(systemName: self.weather.systemImageName)
            Text(self.weather.temperature.formatted(preference: self.temperaturePreference))
          }
          .font(.title.bold())
          Group {
            Text(self.weather.condition.description)
            let feelsLike = weather.feelsLikeTemperature
              .formatted(preference: self.temperaturePreference)
            Text("Feels Like: \(feelsLike)")
          }
          .foregroundStyle(.secondary)
        }
        Spacer()
      }
    }

    Section {
      WeatherInfoLabel(systemImageName: "humidity.fill", title: "Humidity") {
        Text(self.weather.humidity.formatted(.percent))
      }
    } header: {
      Text("Humidity")
    }

    Section {
      WeatherInfoLabel(systemImageName: "eye.fill", title: "Visibility") {
        Text(self.weather.visibility.formatted())
      }
    } header: {
      Text("Visibility")
    }

    Section {
      WeatherInfoLabel(systemImageName: "cloud.rain.fill", title: "Intensity") {
        Text(self.weather.precipitationIntensity.formatted())
      }
    } header: {
      Text("Precipitation")
    }

    Section {
      WeatherInfoLabel(systemImageName: "gauge.with.dots.needle.33percent", title: "Direction") {
        Text(self.weather.wind.direction.description)
      }
      WeatherInfoLabel(systemImageName: "wind", title: "Speed") {
        Text(self.weather.wind.speed.formatted())
      }
    } header: {
      Text("Wind")
    }

    Section {
      WeatherInfoLabel(systemImageName: "thermometer.tirepressure", title: "Amount") {
        Text(self.weather.pressure.amount.formatted())
      }
      WeatherInfoLabel(systemImageName: "chart.line.uptrend.xyaxis", title: "Trend") {
        Text(self.weather.pressure.trend.description)
      }
    } header: {
      Text("Pressure")
    }

    Section {
      WeatherInfoLabel(systemImageName: "rays", title: "Amount") {
        Text("\(self.weather.uvIndex.amount)")
      }
      WeatherInfoLabel(systemImageName: "allergens.fill", title: "Exposure") {
        Text(self.weather.uvIndex.exposureCategory.description)
      }
    } header: {
      Text("UV Index")
    }

    Section {
      WeatherInfoLabel(systemImageName: "water.waves", title: "Low Altitude") {
        Text(self.weather.cloudCover.lowAltitude.formatted(.percent))
      }
      WeatherInfoLabel(systemImageName: "mountain.2.fill", title: "Medium Altitude") {
        Text(self.weather.cloudCover.midAltitude.formatted(.percent))
      }
      WeatherInfoLabel(systemImageName: "airplane.cloud", title: "High Altitude") {
        Text(self.weather.cloudCover.highAltitude.formatted(.percent))
      }
    } header: {
      Text("Cloud Cover")
    }
  }
}

private struct WeatherInfoLabel<Content: View>: View {
  let systemImageName: String
  let title: LocalizedStringKey
  @ViewBuilder let content: () -> Content

  @ScaledMetric private var imageSize = CGFloat(30)

  var body: some View {
    HStack(alignment: .center) {
      Image(systemName: self.systemImageName)
        .frame(width: self.imageSize)
      Text(self.title)

      Spacer()

      self.content()
    }
  }
}

#Preview {
  let userLocation = LocationReading.mock()
  let _ = prepareDependencies {
    $0.defaultDatabase = try! canIClimbDatabase()
    try! $0.defaultDatabase.write { db in
      try SettingsRecord.update(in: db) { $0.temperaturePreference = .celsius }
    }

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
