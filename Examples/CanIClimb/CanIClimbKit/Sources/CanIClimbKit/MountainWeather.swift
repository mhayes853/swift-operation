import Dependencies
import SQLiteData
import SharingOperation
import SwiftUI
import SwiftUINavigation

private struct WeatherDetail: Identifiable, Sendable {
  enum ID: Hashable, Sendable {
    case user
    case mountain(Mountain.ID)
  }

  let id: ID
  let systemImageName: String
  let locationName: LocalizedStringResource
  let unauthorizedText: LocalizedStringResource?
  @SharedOperation<QueryState<WeatherReading, any Error>> var reading: WeatherReading?
}

// MARK: - MountainWeatherView

public struct MountainWeatherView: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @SharedOperation(LocationReading.userQuery) private var userLocation
  @State private var destination: WeatherDetail?

  private let mountain: Mountain

  public init(mountain: Mountain) {
    self.mountain = mountain
  }

  public var body: some View {
    Group {
      if self.dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading) {
          WeatherSnippetView(
            detail: self.userWeatherDetail,
            destination: self.$destination
          )
          Divider()
          WeatherSnippetView(
            detail: self.mountainWeatherDetail,
            destination: self.$destination
          )
          WeatherAttributionView()
        }
      } else {
        VStack {
          HStack {
            VStack {
              WeatherSnippetView(
                detail: self.userWeatherDetail,
                destination: self.$destination
              )
              Spacer()
            }
            .frame(maxWidth: .infinity)
            Divider()
              .padding(.horizontal)
            VStack {
              WeatherSnippetView(
                detail: self.mountainWeatherDetail,
                destination: self.$destination
              )
              Spacer()
            }
            .frame(maxWidth: .infinity)
          }
          HStack {
            Spacer()
            WeatherAttributionView()
            Spacer()
          }
        }
      }
    }
    .sheet(item: self.$destination) { detail in
      NavigationStack {
        WeatherDetailView(detail: detail)
          .dismissable()
      }
    }
  }

  private var userWeatherDetail: WeatherDetail {
    switch self.$userLocation.status {
    case .result(.success(let location)):
      self.userWeatherDetail(location: location)
    case .result(.failure(let error)):
      WeatherDetail(
        id: .user,
        systemImageName: "location.fill",
        locationName: "Your Location",
        unauthorizedText: error is UserLocationUnauthorizedError
          ? "Your location access has been denied."
          : nil,
        reading: SharedOperation()
      )
    case .loading:
      self.userLocation.map { self.userWeatherDetail(location: $0) }
        ?? WeatherDetail.user
    default:
      WeatherDetail.user
    }
  }

  private func userWeatherDetail(location: LocationReading) -> WeatherDetail {
    WeatherDetail(
      id: .user,
      systemImageName: "location.fill",
      locationName: "Your Location",
      unauthorizedText: nil,
      reading: SharedOperation(
        WeatherReading.$currentQuery(for: location.coordinate),
        animation: .bouncy
      )
    )
  }

  private var mountainWeatherDetail: WeatherDetail {
    WeatherDetail(
      id: .mountain(self.mountain.id),
      systemImageName: "mappin.and.ellipse",
      locationName: self.mountain.location.name.localizedStringResource,
      unauthorizedText: nil,
      reading: SharedOperation(
        WeatherReading.$currentQuery(for: self.mountain.location.coordinate),
        animation: .bouncy
      )
    )
  }
}

extension WeatherDetail {
  fileprivate static var user: Self {
    Self(
      id: .user,
      systemImageName: "location.fill",
      locationName: "Your Location",
      unauthorizedText: nil,
      reading: SharedOperation()
    )
  }
}

// MARK: - WeatherSnippetView

private struct WeatherSnippetView: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  @SingleRow(SettingsRecord.self) private var settings

  let detail: WeatherDetail
  @Binding var destination: WeatherDetail?

  @ScaledMetric private var locationSize = CGFloat(40)

  var body: some View {
    let details = VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .center) {
        Image(systemName: self.detail.systemImageName)
        Text(self.detail.locationName)
      }
      .font(.footnote.bold())
      .foregroundStyle(.secondary)
      .frame(height: self.locationSize)

      if let unauthorizedText = self.detail.unauthorizedText {
        Text(unauthorizedText)
      } else {
        switch self.detail.$reading.status {
        case .result(.success(let weather)):
          VStack(alignment: .leading) {
            HStack(alignment: .center) {
              Image(systemName: weather.systemImageName)
              Text(weather.temperature.formatted(preference: self.settings.temperaturePreference))
            }
            .font(.title3.bold())
            Group {
              Text(weather.condition.description)
              let feelsLike = weather.feelsLikeTemperature
                .formatted(preference: self.settings.temperaturePreference)
              Text("Feels Like: \(feelsLike)")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
          }
        case .result(.failure):
          Text("--")
            .foregroundStyle(.secondary)

        default:
          HStack {
            Spacer()
            SpinnerView()
            Spacer()
          }
        }
      }
    }

    Button {
      self.destination = self.detail
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
  let detail: WeatherDetail

  @SingleRow(SettingsRecord.self) var settings

  var body: some View {
    Form {
      if let unauthorizedText = self.detail.unauthorizedText {
        Text(unauthorizedText)
      } else if self.detail.$reading.isBacked {
        RemoteOperationStateView(self.detail.$reading) { weather in
          WeatherReadingFormView(weather: weather)
          Section {
            HStack {
              Spacer()
              WeatherAttributionView()
              Spacer()
            }
          }
        }
      } else {
        HStack {
          Spacer()
          SpinnerView()
          Spacer()
        }
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

      #if os(iOS)
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Picker("Temperature Units", selection: self.$settings.temperaturePreference) {
              ForEach(SettingsRecord.TemperaturePreference.allCases, id: \.self) { preference in
                Text(preference.localizedStringResource)
                  .tag(preference)
              }
            }

            Picker("Measurement Units", selection: self.$settings.metricPreference) {
              ForEach(SettingsRecord.MetricPreference.allCases, id: \.self) { preference in
                Text(preference.localizedStringResource)
                  .tag(preference)
              }
            }
          } label: {
            Image(systemName: "thermometer.high")
          }
        }
      #endif
    }
  }
}

// MARK: - WeatherReadingFormView

private struct WeatherReadingFormView: View {
  let weather: WeatherReading

  @SingleRow(SettingsRecord.self) private var settings

  var body: some View {
    Section {
      HStack {
        Spacer()
        VStack(alignment: .leading) {
          HStack(alignment: .center) {
            Image(systemName: self.weather.systemImageName)
            Text(
              self.weather.temperature.formatted(preference: self.settings.temperaturePreference)
            )
          }
          .font(.title.bold())
          Group {
            Text(self.weather.condition.description)
            let feelsLike = weather.feelsLikeTemperature
              .formatted(preference: self.settings.temperaturePreference)
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
        Text(
          self.weather.visibility.longLengthFormatted(preference: self.settings.metricPreference)
        )
      }
    } header: {
      Text("Visibility")
    }

    Section {
      WeatherInfoLabel(systemImageName: "cloud.rain.fill", title: "Intensity") {
        Text(
          self.weather.precipitationIntensity.formatted(preference: self.settings.metricPreference)
        )
      }
    } header: {
      Text("Precipitation")
    }

    Section {
      WeatherInfoLabel(systemImageName: "gauge.with.dots.needle.33percent", title: "Direction") {
        Text(self.weather.wind.direction.description)
      }
      WeatherInfoLabel(systemImageName: "wind", title: "Speed") {
        Text(self.weather.wind.speed.formatted(preference: self.settings.metricPreference))
      }
    } header: {
      Text("Wind")
    }

    Section {
      WeatherInfoLabel(systemImageName: "thermometer.tirepressure", title: "Amount") {
        Text(self.weather.pressure.amount.formatted(preference: self.settings.metricPreference))
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
        .foregroundStyle(.secondary)
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

    let weather = MockWeatherForecaster()
    weather.readingResults[userLocation.coordinate] = .success(.mock(location: userLocation))
    weather.readingResults[Mountain.mock1.location.coordinate] = .success(
      .mock(location: .mock(coordinate: Mountain.mock1.location.coordinate))
    )
    $0[WeatherForecasterKey.self] = weather
  }

  MountainWeatherView(mountain: Mountain.mock1)
}
