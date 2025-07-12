import CloudKit
import Dependencies
import Observation
import SharingGRDB
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - SettingsModel

@MainActor
@Observable
public final class SettingsModel {
  @ObservationIgnored
  @Fetch(wrappedValue: SettingsRecord(), .singleRow(SettingsRecord.self)) private var _settings

  @ObservationIgnored
  @Fetch(wrappedValue: UserHumanityRecord(), .singleRow(UserHumanityRecord.self))
  private var _userProfile

  @ObservationIgnored
  @Dependency(\.defaultDatabase) private var database

  public var settings: SettingsRecord {
    get { self._settings }
    set { try? self.database.write { try newValue.save(in: $0) } }
  }

  public var userProfile: UserHumanityRecord {
    get { self._userProfile }
    set { try? self.database.write { try newValue.save(in: $0) } }
  }

  public let connectToHealthKit = ConnectToHealthKitModel()

  public init() {}
}

// MARK: - SettingsView

public struct SettingsView: View {
  @Bindable var model: SettingsModel

  public var body: some View {
    Form {
      CloudSyncSectionView()
      AIAvailabilitySectionView()
      ConnectHealthKitSectionView(isConnected: self.model.connectToHealthKit.isConnected) {
        Task { await self.model.connectToHealthKit.connectInvoked() }
      }
      PreferencesSectionView(settings: self.$model.settings)
      UserInfoSectionView(
        profile: self.$model.userProfile,
        metricPreference: self.model.settings.metricPreference
      )
      SocialsSectionView()
      DisclaimerSectionView()
    }
    .navigationTitle("Settings")
    .dismissable()
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
  }
}

// MARK: - CloudSyncSectionView

private struct CloudSyncSectionView: View {
  @SharedQuery(CKAccountStatus.currentQuery, animation: .bouncy) private var accountStatus

  public var body: some View {
    Section {
      Label {
        HStack {
          switch self.$accountStatus.status {
          case .result(.success(.available)):
            Text("Active")
          case .result(.success(.noAccount)):
            Text("Not Available")
          case .result(.success(.restricted)):
            Text("Restricted")
          case .result(.success(.temporarilyUnavailable)):
            Text("Temporarily Unavailable")
          case .result(.failure), .result(.success(.couldNotDetermine)):
            Text("Cannot Determine")
          default:
            Text("Loading...")
          }
          Spacer()
          if !self.$accountStatus.isLoading {
            AvailabilityCircleView(isAvailable: self.accountStatus == .available)
          }
        }
      } icon: {
        Group {
          switch self.$accountStatus.status {
          case .result(.success(.available)):
            Image(systemName: "checkmark.icloud.fill")
          case .result(.success(.restricted)):
            Image(systemName: "lock.icloud.fill")
          case .result(.success(.temporarilyUnavailable)):
            Image(systemName: "exclamationmark.icloud.fill")
          case .result(.failure), .result(.success(.couldNotDetermine)),
            .result(.success(.noAccount)):
            Image(systemName: "xmark.icloud.fill")
          default:
            ProgressView()
          }
        }
        .symbolRenderingMode(.multicolor)
        .foregroundStyle(Color.accentColor.gradient)
      }

      if self.accountStatus == .temporarilyUnavailable {
        Link("Open Settings", destination: settingsURL)
      }
    } header: {
      Text("iCloud Sync Status")
    } footer: {
      switch self.$accountStatus.status {
      case .result(.success(.available)):
        Text(
          """
          iCloud Sync is available, and should be active. Though you may need to occasionally \
          relaunch the app on the simulator to see changes synced in real time.
          """
        )
      case .result(.success(.noAccount)):
        Text(
          "You must be signed into your iCloud account to sync data with your \(localizedModelName)."
        )
      case .result(.success(.temporarilyUnavailable)):
        Text("You need to verify your iCloud account in settings.")
      case .result(.success(.restricted)):
        Text(
          """
          CanIClimb was denied access to your iCloud account. This may be because your \
          \(localizedModelName) has parental control restrictions, or is owned by a company or \
          educational institution.
          """
        )
      case .result(.failure), .result(.success(.couldNotDetermine)):
        Text("The status of your iCloud account could not be determined. Please try again later.")
      default:
        EmptyView()
      }
    }
  }
}

// MARK: - AIAvailabilitySecion

private struct AIAvailabilitySectionView: View {
  @Environment(\.systemLanguageModelAvailability) var availability

  public var body: some View {
    Section {
      Label {
        HStack {
          switch self.availability {
          case .available:
            Text("Available")
          case .unavailable(.appleIntelligenceNotEnabled):
            Text("Apple Intelligence Not Enabled")
          case .unavailable(.modelNotReady):
            Text("Model Not Ready")
          default:
            Text("Unavailable")
          }
          Spacer()
          AvailabilityCircleView(isAvailable: self.availability == .available)
        }
      } icon: {
        Image(systemName: "bubbles.and.sparkles.fill")
          .symbolRenderingMode(.multicolor)
          .foregroundStyle(Color.accentColor.gradient)
      }

      if self.availability == .unavailable(.appleIntelligenceNotEnabled) {
        Link("Open Settings", destination: settingsURL)
      }
    } header: {
      Text("CanIClimb AI Availability")
    } footer: {
      switch self.availability {
      case .available:
        Text(
          """
          Apple Intelligence is enabled and ready to use on your \(localizedModelName), have fun \
          climbing!
          """
        )
      case .unavailable(.appleIntelligenceNotEnabled):
        Text(
          """
          Apple Intelligence is available for your \(localizedModelName), but it is not enabled. \
          Go to settings and enable Apple Intelligence to access features such as personalized \
          training plans!
          """
        )
      case .unavailable(.modelNotReady):
        Text(
          """
          Apple Intelligence is enabled on your \(localizedModelName), but the model is readying \
          itself. Please wait and check back later.
          """
        )
      default:
        Text("Apple Intelligence is unavailable on your \(localizedModelName).")
      }
    }
  }
}

// MARK: - Connect HealtKit Section

private struct ConnectHealthKitSectionView: View {
  let isConnected: Bool
  let onConnect: () -> Void

  var body: some View {
    Section {
      if self.isConnected {
        Label {
          Text("Connected")
        } icon: {
          Image(systemName: "heart.text.square.fill")
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(.secondary)
      } else {
        Button {
          self.onConnect()
        } label: {
          Label {
            Text("Connect to HealthKit")
          } icon: {
            Image(systemName: "heart.text.square.fill")
              .foregroundStyle(.pink)
          }
        }
      }
    } header: {
      Text("HealthKit")
    } footer: {
      if self.isConnected {
        Text("HealthKit is connected, and will be used to personalize your training plans.")
      } else {
        Text(
          "Connect to HealthKit to personalize your training plans based on your personal health data."
        )
      }
    }
    .tint(.pink)
  }
}

// MARK: - Preferences Section

private struct PreferencesSectionView: View {
  @Binding var settings: SettingsRecord

  var body: some View {
    Section {
      Picker("Measurement Units", selection: $settings.metricPreference) {
        ForEach(SettingsRecord.MetricPreference.allCases, id: \.self) { preference in
          Text(preference.localizedString)
            .tag(preference)
        }
      }
      Picker("Temperature Units", selection: $settings.temperaturePreference) {
        ForEach(SettingsRecord.TemperaturePreference.allCases, id: \.self) { preference in
          Text(preference.localizedString)
            .tag(preference)
        }
      }
    } header: {
      Text("Preferences")
    }
  }
}

extension SettingsRecord.MetricPreference {
  fileprivate var localizedString: LocalizedStringKey {
    switch self {
    case .metric: "Metric (cm, kg)"
    case .imperial: "Imperial (ft, lbs)"
    }
  }
}

extension SettingsRecord.TemperaturePreference {
  fileprivate var localizedString: LocalizedStringKey {
    switch self {
    case .celsius: "Celsius"
    case .fahrenheit: "Fahrenheit"
    case .kelvin: "Kelvin"
    }
  }
}

// MARK: - User Profile Section

private struct UserInfoSectionView: View {
  @Binding var profile: UserHumanityRecord
  let metricPreference: SettingsRecord.MetricPreference

  var body: some View {
    Section {
      Picker("Gender", selection: self.$profile.gender) {
        ForEach(HumanGender.allCases, id: \.self) { gender in
          Text(gender.localizedString)
            .tag(gender)
        }
      }

      Picker("Age Range", selection: self.$profile.ageRange) {
        ForEach(HumanAgeRange.allCases, id: \.self) { ageRange in
          Text(ageRange.localizedString)
            .tag(ageRange)
        }
      }

      switch self.metricPreference {
      case .imperial:
        Picker("Height", selection: self.$profile.height.imperial) {
          ForEach(HumanHeight.Imperial.options, id: \.self) { height in
            Text(height.formatted)
              .tag(height)
          }
        }
      case .metric:
        Picker("Height", selection: self.$profile.height.metric) {
          ForEach(HumanHeight.Metric.options, id: \.self) { height in
            Text(height.formatted)
              .tag(height)
          }
        }
      }

      switch self.metricPreference {
      case .imperial:
        Stepper(
          "Weight (\(self.profile.weight.displayedPounds) lbs)",
          value: self.$profile.weight.displayedPounds,
          in: 0...600
        )
      case .metric:
        Stepper(
          "Weight (\(self.profile.weight.displayedKilograms) kg)",
          value: self.$profile.weight.displayedKilograms,
          in: 0...272
        )
      }

      Picker("Activity Level", selection: self.$profile.activityLevel) {
        ForEach(HumanActivityLevel.allCases, id: \.self) { activityLevel in
          Text(activityLevel.localizedString)
            .tag(activityLevel)
        }
      }

      Picker("Workout Frequency", selection: self.$profile.workoutFrequency) {
        ForEach(HumanWorkoutFrequency.allCases, id: \.self) { frequency in
          Text(frequency.localizedString)
            .tag(frequency)
        }
      }
    } header: {
      Text("Info")
    }
  }
}

extension Measurement where UnitType == UnitMass {
  fileprivate var displayedPounds: Int {
    get { Int(self.converted(to: .pounds).value) }
    set { self = Measurement(value: Double(newValue), unit: .pounds) }
  }

  fileprivate var displayedKilograms: Int {
    get { Int(self.converted(to: .kilograms).value) }
    set { self = Measurement(value: Double(newValue), unit: .kilograms) }
  }
}

// MARK: - Socials Section

private struct SocialsSectionView: View {
  var body: some View {
    Section {
      Link("Github Repo", destination: URL(string: "https://github.com/mhayes853/swift-query")!)
      Link("Introduction Blog Post", destination: URL(string: "https://whypeople.xyz/swift-query")!)
      Link(
        "Source Code (for this demo app)",
        destination: URL(string: "https://github.com/mhayes853/swift-query")!
      )
    } header: {
      Text("Learn More")
    } footer: {
      Text(
        """
        This demo app was built to showcase Swift Query alongside other libraries in a moderately \
        complex application. Check out the links to learn more.
        """
      )
    }
  }
}

// MARK: - Disclaimer Section

private struct DisclaimerSectionView: View {
  var body: some View {
    Section {
      Text(
        """
        CanIClimb is just an application for demonstration purposes that shows how to integrate \
        Swift Query into a moderately complex application involving personalized data. Please \
        consult with a licensed professional for accurate and personalized advice.
        """
      )
    } header: {
      Text("Disclaimer")
    }
  }
}

#Preview {
  @Previewable @State var isPresented = true

  let _ = prepareDependencies {
    $0[CKAccountStatus.LoaderKey.self] = CKAccountStatus.MockLoader {
      try await Task.sleep(for: .seconds(1))
      return .available
    }
    $0.defaultDatabase = try! canIClimbDatabase()

    var requester = HealthPermissions.MockRequester()
    // requester.shouldFail = true
    $0[HealthPermissions.self] = HealthPermissions(
      database: $0.defaultDatabase,
      requester: requester
    )
  }

  Button("Present Settings") {
    isPresented = true
  }
  .sheet(isPresented: $isPresented) {
    NavigationStack {
      SettingsView(model: SettingsModel())
    }
  }
  .observeQueryAlerts()
}
