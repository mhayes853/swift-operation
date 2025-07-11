import Observation
import SharingGRDB
import SharingQuery
import SwiftUI

// MARK: - OnboardingModel

@MainActor
@Observable
public final class OnboardingModel {
  @ObservationIgnored
  public var onFinished: (() -> Void)?

  public var path = [Path]()

  public let connectToHealthKit = ConnectToHealthKitModel()

  public private(set) var userProfile = UserHumanityRecord()

  @ObservationIgnored
  private var didSelectedGender = false

  @ObservationIgnored
  @Dependency(\.defaultDatabase) private var database

  @ObservationIgnored
  @SharedQuery(LocationReading.requestUserPermissionMutation) private var requestLocationPermission

  @ObservationIgnored
  @Fetch(wrappedValue: SettingsRecord(), .singleRow(SettingsRecord.self)) private var _settings

  public init() {}
}

extension OnboardingModel {
  public var metricPreference: SettingsRecord.MetricPreference {
    get { self._settings.metricPreference }
    set {
      try? self.database.write { db in
        try SettingsRecord.update(in: db) { $0.metricPreference = newValue }
      }
    }
  }
}

extension OnboardingModel {
  public func startInvoked() {
    self.path.append(.selectGender)
  }

  public func genderSelected(_ gender: HumanGender) {
    if !self.didSelectedGender {
      self.userProfile.height = gender.averages.height
      self.userProfile.weight = gender.averages.weight
    }

    self.didSelectedGender = true
    self.userProfile.gender = gender
    self.path.append(.selectAgeRange)
  }

  public func ageRangeSelected(_ ageRange: HumanAgeRange) {
    self.userProfile.ageRange = ageRange
    self.path.append(.selectHeight)
  }

  public func heightSelected(_ height: HumanHeight) {
    self.userProfile.height = height
    self.path.append(.selectWeight)
  }

  public func weightSelected(_ weight: Measurement<UnitMass>) {
    self.userProfile.weight = weight
    self.path.append(.selectActivityLevel)
  }

  public func activityLevelSelected(_ activityLevel: HumanActivityLevel) {
    self.userProfile.activityLevel = activityLevel
    self.path.append(.selectWorkoutFrequency)
  }

  public func workoutFrequencySelected(_ workoutFrequency: HumanWorkoutFrequency) {
    self.userProfile.workoutFrequency = workoutFrequency
    self.path.append(.connectHealthKit)
  }

  public func wrapUpInvoked() async throws {
    try await self.database.write { [userProfile] db in
      try userProfile.save(in: db)

      var internalMetrics = InternalMetricsRecord.find(in: db)
      internalMetrics.hasCompletedOnboarding = true
      try internalMetrics.save(in: db)
    }
    self.onFinished?()
  }
}

extension OnboardingModel {
  public enum ConnectToHealthKitStepAction: Hashable {
    case connect
    case skip
  }

  public func connectToHealthKitStepInvoked(action: ConnectToHealthKitStepAction) async {
    switch action {
    case .connect:
      await self.connectToHealthKit.connectInvoked()
    case .skip:
      break
    }
    self.path.append(.shareLocation)
  }
}

extension OnboardingModel {
  public enum LocationPermissionStepAction: Hashable {
    case requestPermission
    case skip
  }

  public func locationPermissionStepInvoked(action: LocationPermissionStepAction) async {
    switch action {
    case .requestPermission:
      _ = try? await self.$requestLocationPermission.mutate()
    case .skip:
      break
    }
    self.path.append(.accountCreation)
  }
}

extension OnboardingModel {
  public enum AccountStepAction: Hashable {
    case skip
    case signIn(User.SignInCredentials)
  }

  public func accountStepInvoked(action: AccountStepAction) {
    // TODO: - Sign In With Apple
    self.path.append(.wrapUp)
  }
}

extension OnboardingModel {
  public enum Path: Hashable, Sendable {
    case selectGender
    case selectAgeRange
    case selectHeight
    case selectWeight
    case selectActivityLevel
    case selectWorkoutFrequency
    case connectHealthKit
    case shareLocation
    case accountCreation
    case wrapUp
  }
}

// MARK: - OnboardingView

public struct OnboardingView: View {
  @Bindable var model: OnboardingModel

  public var body: some View {
    NavigationStack(path: self.$model.path) {
      EmptyView()
    }
  }
}
