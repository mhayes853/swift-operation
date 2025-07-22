import Observation
import SharingGRDB
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - OnboardingModel

@MainActor
@Observable
public final class OnboardingModel: HashableObject, Identifiable {
  public var path = [Path]()
  public var hasAcceptedDisclaimer = false
  public let connectToHealthKit = ConnectToHealthKitModel()
  public let signIn = SignInModel()
  public var userProfile = UserHumanityRecord()

  @ObservationIgnored
  public var onFinished: (() -> Void)?

  @ObservationIgnored
  private var didSelectedGender = false

  @ObservationIgnored
  @Dependency(\.defaultDatabase) private var database

  @ObservationIgnored
  @SharedQuery(LocationReading.requestUserPermissionMutation) private var requestLocationPermission

  @ObservationIgnored
  @Fetch(wrappedValue: SettingsRecord(), .singleRow(SettingsRecord.self)) private var _settings

  public init() {
    self.signIn.onSignInSuccess = { [weak self] in self?.path.append(.wrapUp) }
  }
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
  public var hasRequestedLocationSharing: Bool {
    self.requestLocationPermission != nil
  }

  public var isLocationSharingEnabled: Bool {
    self.requestLocationPermission == true
  }
}

extension OnboardingModel {
  public func startInvoked() {
    self.path.append(.disclaimer)
  }

  public func disclaimerAccepted() {
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

  public func heightSelected() {
    self.path.append(.selectWeight)
  }

  public func weightSelected() {
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

  public func connectToHealthKitStepInvoked(action: ConnectToHealthKitStepAction) async {
    switch action {
    case .connect:
      await self.connectToHealthKit.connectInvoked()
    case .skip:
      break
    }
    self.path.append(.shareLocation)
  }

  public func locationPermissionStepInvoked(action: LocationPermissionStepAction) async {
    switch action {
    case .requestPermission:
      _ = try? await self.$requestLocationPermission.mutate()
    case .skip:
      break
    }
    self.path.append(.signIn)
  }

  public func signInSkipped() {
    self.path.append(.wrapUp)
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
}

extension OnboardingModel {
  public enum LocationPermissionStepAction: Hashable {
    case requestPermission
    case skip
  }
}

extension OnboardingModel {
  public enum Path: Hashable, Sendable {
    case disclaimer
    case selectGender
    case selectAgeRange
    case selectHeight
    case selectWeight
    case selectActivityLevel
    case selectWorkoutFrequency
    case connectHealthKit
    case shareLocation
    case signIn
    case wrapUp
  }
}

// MARK: - OnboardingView

public struct OnboardingView: View {
  @Bindable private var model: OnboardingModel

  public init(model: OnboardingModel) {
    self.model = model
  }

  public var body: some View {
    NavigationStack(path: self.$model.path) {
      WelcomeView(model: self.model)
        .navigationDestination(for: OnboardingModel.Path.self) { path in
          switch path {
          case .disclaimer:
            DisclaimerView(model: self.model)
          case .selectGender:
            GenderSelectionView(model: self.model)
          case .selectAgeRange:
            AgeRangeSelectionView(model: self.model)
          case .selectHeight:
            HeightSelectionView(model: self.model)
          case .selectWeight:
            WeightSelectionView(model: self.model)
          case .selectActivityLevel:
            ActivitiyLevelSelectionView(model: self.model)
          case .selectWorkoutFrequency:
            WorkoutFrequencySelectionView(model: self.model)
          case .connectHealthKit:
            ConnectHealthKitView(model: self.model)
          case .shareLocation:
            ShareLocationView(model: self.model)
          case .signIn:
            SignInView(model: self.model)
          case .wrapUp:
            WrapUpView(model: self.model)
          }
        }
    }
  }
}

// MARK: - WelcomeView

private struct WelcomeView: View {
  let model: OnboardingModel

  var body: some View {
    OnboardingImageActionView(
      title: "Can I Climb?",
      subtitle: """
        You'll climb yourself up that mountain in no time! But first, we need to know a few things about you.
        """,
      systemImageName: "mountain.2.fill",
      imageColor: .primary
    ) {
      OnboardingButton("Let's Get Started!") {
        self.model.startInvoked()
      }
    }
    .onboardingNavigationTitle("Welcome")
  }
}

// MARK: - DisclaimerView

private struct DisclaimerView: View {
  @Bindable var model: OnboardingModel

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        Text("DISCLAIMER").font(.title.bold())
        Text(disclaimer)
        Toggle("I Understand and Accept", isOn: self.$model.hasAcceptedDisclaimer)
          .frame(maxWidth: .infinity)
          .bold()
          .padding()
          .background(Color.secondaryBackground)
          .cornerRadius(10)
      }
      .padding()
    }
    .safeAreaInset(edge: .bottom) {
      OnboardingButton("Let's Move On") {
        self.model.disclaimerAccepted()
      }
      .padding()
      .disabled(!self.model.hasAcceptedDisclaimer)
    }
    .onboardingNavigationTitle("DISCLAIMER")
  }
}

// MARK: - GenderSelectionView

private struct GenderSelectionView: View {
  let model: OnboardingModel

  var body: some View {
    OnboardingOptionsPicker(title: "Select Your Gender", options: Array(HumanGender.allCases)) {
      self.model.genderSelected($0)
    }
    .onboardingNavigationTitle("Gender")
  }
}

// MARK: - AgeRangeSelectionView

private struct AgeRangeSelectionView: View {
  let model: OnboardingModel

  var body: some View {
    OnboardingOptionsPicker(title: "Select Your Age", options: Array(HumanAgeRange.allCases)) {
      self.model.ageRangeSelected($0)
    }
    .onboardingNavigationTitle("Age")
  }
}

// MARK: - HeightSelectionView

private struct HeightSelectionView: View {
  @Bindable var model: OnboardingModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        Text("Select Your Weight").font(.title.bold())
        Spacer()
        Group {
          switch self.model.metricPreference {
          case .imperial:
            Picker("Select Your Height", selection: self.$model.userProfile.height.imperial) {
              ForEach(HumanHeight.Imperial.options, id: \.self) { height in
                Text(height.formatted)
                  .tag(height)
              }
            }
          case .metric:
            Picker("Select Your Height", selection: self.$model.userProfile.height.metric) {
              ForEach(HumanHeight.Metric.options, id: \.self) { height in
                Text(height.formatted)
                  .tag(height)
              }
            }
          }
        }
        #if os(iOS)
          .pickerStyle(.wheel)
        #endif
        OnboardingMetricPreferencePickerView(metricPreference: self.$model.metricPreference)
        Spacer()
      }
      .padding()
    }
    .safeAreaInset(edge: .bottom) {
      OnboardingButton("Select Height") {
        self.model.heightSelected()
      }
      .padding()
    }
    .onboardingNavigationTitle("Height")
  }
}

// MARK: - WeightSelectionView

private struct WeightSelectionView: View {
  @Bindable var model: OnboardingModel

  // NB: SwiftUI Pickers will reset a Measurement binding to 0 when the metric preference changes,
  // so use a raw numerical value instead.
  @State private var selectedValue: Int

  init(model: OnboardingModel) {
    self.model = model
    self._selectedValue = State(
      initialValue: Int(model.userProfile.weight.converted(to: model.metricPreference.unit).value)
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        Text("Select Your Weight").font(.title.bold())
        Spacer()
        Group {
          Picker("Select Your Weight", selection: self.$selectedValue.animation()) {
            switch self.model.metricPreference {
            case .imperial:
              ForEach(0..<601) { value in
                Text("\(value) lbs")
                  .tag(value)
              }
            case .metric:
              ForEach(0..<273) { value in
                Text("\(value) kg")
                  .tag(value)
              }
            }
          }
        }
        #if os(iOS)
          .pickerStyle(.wheel)
        #endif
        OnboardingMetricPreferencePickerView(metricPreference: self.$model.metricPreference)
          .onChange(of: self.model.metricPreference) { old, new in
            let oldMeasurement = Measurement<UnitMass>(
              value: Double(self.selectedValue),
              unit: old.unit
            )
            self.selectedValue = Int(oldMeasurement.converted(to: new.unit).value)
          }
          .onChange(of: self.selectedValue) {
            self.model.userProfile.weight = Measurement(
              value: Double(self.selectedValue),
              unit: self.model.metricPreference.unit
            )
          }
        OnboardingBMIView(bmi: self.model.userProfile.bmi)
        Spacer()
      }
      .padding()
    }
    .safeAreaInset(edge: .bottom) {
      OnboardingButton("Select Weight") {
        self.model.weightSelected()
      }
      .padding()
    }
    .onboardingNavigationTitle("Weight")
  }
}

// MARK: - ActivityLevelSelectionView

private struct ActivitiyLevelSelectionView: View {
  let model: OnboardingModel

  var body: some View {
    OnboardingOptionsPicker(
      title: "Select Your Activity Level",
      subtitle:
        "How would you best describe how physically active your are? Pick the option that you think best suits your lifestyle.",
      options: Array(HumanActivityLevel.allCases)
    ) {
      self.model.activityLevelSelected($0)
    }
    .onboardingNavigationTitle("Activity Level")
  }
}

// MARK: - WorkoutFrequencySelectionView

private struct WorkoutFrequencySelectionView: View {
  let model: OnboardingModel

  var body: some View {
    OnboardingOptionsPicker(
      title: "How Often do you Exercise?",
      options: Array(HumanWorkoutFrequency.allCases)
    ) {
      self.model.workoutFrequencySelected($0)
    }
    .onboardingNavigationTitle("Exercise Frequency")
  }
}

// MARK: - ConnectHealthKitView

private struct ConnectHealthKitView: View {
  let model: OnboardingModel

  var body: some View {
    OnboardingImageActionView(
      title: LocalizedStringResource("Connect HealthKit"),
      subtitle: LocalizedStringResource(
        """
        Connecting HealthKit will allow us to use your health data to provide personalized \
        recommendations and insights. Your health data does not leave your device.
        """
      ),
      systemImageName: "heart.text.clipboard.fill",
      imageColor: .pink
    ) {
      VStack(spacing: 20) {
        OnboardingButton(
          self.model.connectToHealthKit.isConnected ? "HealthKit Connected" : "Connect HealthKit"
        ) {
          Task { await self.model.connectToHealthKitStepInvoked(action: .connect) }
        }
        .disabled(self.model.connectToHealthKit.isConnected)
        Button(self.model.connectToHealthKit.isConnected ? "Continue" : "Skip") {
          Task { await self.model.connectToHealthKitStepInvoked(action: .skip) }
        }
        .tint(.primary)
        .buttonStyle(.plain)
      }
    }
    .onboardingNavigationTitle("Connect HealthKit")
  }
}

// MARK: - LocationPermissionView

private struct ShareLocationView: View {
  let model: OnboardingModel

  var body: some View {
    OnboardingImageActionView(
      title: LocalizedStringResource("Share Your Location"),
      subtitle: LocalizedStringResource(
        """
        Sharing your location will allow us to show distance, travel estimate, weather, and \
        elevation data. Your location is not shared with anyone.
        """
      ),
      systemImageName: "location.fill",
      imageColor: .blue
    ) {
      VStack(spacing: 20) {
        if self.model.hasRequestedLocationSharing {
          OnboardingButton(
            self.model.isLocationSharingEnabled
              ? "Location Sharing Enabled" : "Location Sharing Disabled"
          ) {
            Task { await self.model.locationPermissionStepInvoked(action: .skip) }
          }
          .disabled(true)
          Button("Continue") {
            Task { await self.model.locationPermissionStepInvoked(action: .skip) }
          }
          .tint(.primary)
          .buttonStyle(.plain)
        } else {
          OnboardingButton("Share Your Location") {
            Task { await self.model.locationPermissionStepInvoked(action: .requestPermission) }
          }
          Button("Skip") {
            Task { await self.model.locationPermissionStepInvoked(action: .skip) }
          }
          .tint(.primary)
          .buttonStyle(.plain)
        }
      }
    }
    .onboardingNavigationTitle("Location Sharing")
  }
}

// MARK: - SignUpView

private struct SignInView: View {
  let model: OnboardingModel

  var body: some View {
    OnboardingImageActionView(
      title: "Sign In",
      subtitle: """
        Sign in to share your training plans with others!

        **Note:** For demonstration purposes, the app does not connect to a live external server. \
        The code is written in a manner that assumes it would be connecting to such a server, but \
        under the hood in-memory data is returned.
        """,
      systemImageName: "person.crop.circle",
      imageColor: .primary,
    ) {
      VStack(spacing: 20) {
        let isDisabled = self.model.signIn.isSignedIn || self.model.signIn.$signIn.isLoading
        SignInButton(label: .signIn, model: self.model.signIn)
          .opacity(isDisabled ? 0.5 : 1)
          .frame(maxHeight: 60)
          .disabled(isDisabled)
          .padding()
        Button(self.model.signIn.isSignedIn ? "Continue" : "Skip") {
          self.model.signInSkipped()
        }
        .tint(.primary)
        .buttonStyle(.plain)
      }
    }
    .onboardingNavigationTitle("Sign In")
  }
}

extension SignInModel {
  fileprivate var isSignedIn: Bool {
    self.signIn != nil
  }
}

// MARK: - WrapUpView

private struct WrapUpView: View {
  let model: OnboardingModel

  var body: some View {
    OnboardingImageActionView(
      title: "It's Time!",
      subtitle: "We've gotten to know you a bit better! Now let's get climbing!",
      systemImageName: "mountain.2.fill",
      imageColor: .primary
    ) {
      OnboardingButton("Let's Get Climbing Indeed!") {
        Task { await withErrorReporting { try await self.model.wrapUpInvoked() } }
      }
    }
    .onboardingNavigationTitle("Wrap Up")
  }
}

// MARK: - OnboardingIconActionView

private struct OnboardingImageActionView<Actions: View>: View {
  let title: LocalizedStringResource
  let subtitle: LocalizedStringResource
  let systemImageName: String
  let imageColor: Color
  @ViewBuilder let actions: () -> Actions

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        Spacer()
        Image(systemName: self.systemImageName)
          .resizable()
          .scaledToFit()
          .frame(width: 200, height: 200)
          .foregroundStyle(self.imageColor)
          .symbolRenderingMode(.multicolor)
        Text(self.title)
          .font(.largeTitle.bold())
        Text(self.subtitle)
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding()
    }
    .safeAreaInset(edge: .bottom) {
      self.actions()
        .padding()
    }
  }
}

// MARK: - OnboardingBMIView

private struct OnboardingBMIView: View {
  let bmi: HumanBMI

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      Text("BMI: \(self.bmi.score.formatted(.number.precision(.fractionLength(1))))")
        .font(.headline)
      Text(self.bmi.displayDescription)
        .font(.callout)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 10)
        .stroke(self.bmi.backgroundColor, lineWidth: 4)
        .fill(self.bmi.backgroundColor.opacity(0.75))
    }
  }
}

extension HumanBMI {
  fileprivate var backgroundColor: Color {
    switch self.quality {
    case .underweight: .blue
    case .normal: .green
    case .overweight: .yellow
    case .obese: .red
    }
  }

  fileprivate var displayDescription: LocalizedStringResource {
    switch self.quality {
    case .underweight:
      """
      Your BMI indicates that you are underweight. Consider increasing your calorie intake and \
      engaging in regular physical activity to achieve a healthy weight.
      """
    case .normal:
      """
      Your BMI indicates that your weight is within the healthy range for your height. Continue \
      maintaining a balanced diet and regular exercise routine to sustain this healthy weight.
      """
    case .overweight:
      """
      Your BMI indicates that you are overweight. Consider reducing your calorie intake and \
      increasing your physical activity to achieve a healthy weight.
      """
    case .obese:
      """
      Your BMI indicates that you are obese with respect to your weight. Consider reducing your \
      calorie intake and increasing your physical activity to achieve a healthy weight.
      """
    }
  }
}

// MARK: - MetricPreferencePickerView

private struct OnboardingMetricPreferencePickerView: View {
  @Binding var metricPreference: SettingsRecord.MetricPreference

  var body: some View {
    HStack(alignment: .center) {
      Text("Units").font(.headline)
      Spacer()
      Picker("Units", selection: self.$metricPreference) {
        ForEach(SettingsRecord.MetricPreference.allCases, id: \.self) { preference in
          Text(preference.localizedStringResource)
            .tag(preference)
        }
      }
      .tint(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color.secondaryBackground)
    .cornerRadius(10)
  }
}

// MARK: - OnboardingOptionsPicker

private struct OnboardingOptionsPicker<
  Option: CustomLocalizedStringResourceConvertible & Hashable
>: View {
  let title: LocalizedStringKey
  var subtitle: LocalizedStringKey?
  let options: [Option]
  let onSelected: (Option) -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading) {
          Text(self.title).font(.title.bold())
          if let subtitle {
            Text(subtitle)
              .foregroundStyle(.secondary)
          }
        }
        VStack {
          ForEach(options, id: \.self) { option in
            OnboardingOptionView(label: option.localizedStringResource) {
              self.onSelected(option)
            }
          }
        }
      }
      .padding()
    }
  }
}

// MARK: - OnboardingOptionView

private struct OnboardingOptionView: View {
  let label: LocalizedStringResource
  let onSelected: () -> Void

  var body: some View {
    Button(action: self.onSelected) {
      HStack {
        Text(self.label)
          .font(.title2.bold())
        Spacer()
        Image(systemName: "chevron.right")
          .bold()
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 40)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.secondaryBackground)
      .cornerRadius(20)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - OnboardingButton

private struct OnboardingButton: View {
  let action: () -> Void
  let label: String

  init(_ label: String, action: @escaping () -> Void) {
    self.action = action
    self.label = label
  }

  var body: some View {
    Button(action: self.action) {
      Text(self.label)
        .foregroundStyle(.background)
        .bold()
        .padding()
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .tint(.primary)
  }
}

// MARK: - Onboarding Navigation Title

extension View {
  fileprivate func onboardingNavigationTitle(_ title: LocalizedStringResource) -> some View {
    self.navigationTitle(title)
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
  }
}

// MARK: - Colors

extension Color {
  fileprivate static let secondaryBackground = Self.secondary.opacity(0.15)
}

#Preview {
  let _ = prepareDependencies {
    $0.defaultDatabase = try! canIClimbDatabase()
    $0.defaultQueryClient = QueryClient(storeCreator: .canIClimb)

    let authenticator = User.MockAuthenticator()
    authenticator.requiredCredentials = .mock1
    $0[User.AuthenticatorKey.self] = authenticator

    let location = MockUserLocation()
    location.isAuthorized = false
    $0[UserLocationKey.self] = location

    $0[HealthPermissions.self] = HealthPermissions(
      database: $0.defaultDatabase,
      requester: HealthPermissions.MockRequester()
    )
  }

  let model = OnboardingModel()
  // let _ = model.path = [.selectGender]
  OnboardingView(model: model)
    .observeQueryAlerts()
    .environment(\.signInButtonMockCredentials, .mock1)
}
