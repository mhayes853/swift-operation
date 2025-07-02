import CloudKit
import Dependencies
import SharingQuery
import SwiftUI

// MARK: - CloudSyncSectionView

public struct CloudSyncSectionView: View {
  @SharedQuery(CKAccountStatus.currentQuery) private var accountStatus

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
      case .result(.success(let accountStatus)):
        Text(accountStatus.footerText)
      case .result(.failure):
        Text(CKAccountStatus.couldNotDetermine.footerText)
      default:
        EmptyView()
      }
    }
  }
}

// MARK: - Account Footer Text

extension CKAccountStatus {
  @MainActor
  fileprivate var footerText: LocalizedStringKey {
    switch self {
    case .available:
      """
      iCloud Sync is available, and should be active. Though you may need to occasionally \
      relaunch the app on the simulator to see changes synced in real time.
      """
    case .noAccount:
      """
      You must be signed into your iCloud account to sync data with your \(localizedModelName).
      """
    case .restricted:
      """
      CanIClimb was denied access to your iCloud account. This may be because your \
      \(localizedModelName) has parental control restrictions, or is owned by a company or \
      educational institution.
      """
    case .temporarilyUnavailable:
      "You need to verify your iCloud account in settings."
    default:
      "The status of your iCloud account could not be determined. Please try again later."
    }
  }
}

#Preview {
  let _ = prepareDependencies {
    $0[CKAccountStatus.LoaderKey.self] = CKAccountStatus.MockLoader {
      try await Task.sleep(for: .seconds(1))
      return .available
    }
  }

  NavigationStack {
    Form {
      CloudSyncSectionView()
    }
  }
}
