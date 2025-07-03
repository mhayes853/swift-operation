import CloudKit
import Dependencies
import Observation
import SharingGRDB
import SharingQuery
import SwiftUI

// MARK: - SettingsModel

@MainActor
@Observable
public final class SettingsModel {
  @ObservationIgnored
  @Fetch(wrappedValue: SettingsRecord(), .singleRow(SettingsRecord.self)) private var _settings

  @ObservationIgnored
  @Dependency(\.defaultDatabase) private var database

  public var settings: SettingsRecord {
    get { self._settings }
    set { try? self.database.write { try newValue.save(in: $0) } }
  }

  public init() {}
}

// MARK: - SettingsView

public struct SettingsView: View {
  @Environment(\.dismiss) var dismiss
  @Bindable var model: SettingsModel

  public var body: some View {
    Form {
      CloudSyncSectionView()
      AIAvailabilitySectionView()
      PreferencesSectionView(settings: self.$model.settings)
      SocialsSectionView()
    }
    .navigationTitle("Settings")
    .toolbar {
      let button = Button {
        self.dismiss()
      } label: {
        Image(systemName: "xmark")
      }
      #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
          button
        }
      #else
        ToolbarItem(placement: .navigation) {
          button
        }
      #endif
    }
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

#Preview {
  @Previewable @State var isPresented = true

  let _ = prepareDependencies {
    $0[CKAccountStatus.LoaderKey.self] = CKAccountStatus.MockLoader {
      try await Task.sleep(for: .seconds(1))
      return .available
    }
    $0.defaultDatabase = try! canIClimbDatabase()
  }

  Button("Present Settings") {
    isPresented = true
  }
  .sheet(isPresented: $isPresented) {
    NavigationStack {
      SettingsView(model: SettingsModel())
    }
  }
}
