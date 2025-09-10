import Foundation

extension UserHumanityGenerable {
  public init(record: UserHumanityRecord) {
    self.init(
      heightCentimeters: record.height.metric.centimeters,
      weightKilograms: record.weight.converted(to: .kilograms).value,
      ageRange: record.ageRange.generableDescription,
      genderIdentity: record.gender.generableDescription,
      activityLevel: record.activityLevel.generableDescription,
      workoutFrequency: record.workoutFrequency.generableDescription
    )
  }
}

extension HumanAgeRange {
  fileprivate var generableDescription: String {
    switch self {
    case .in20s: "20s"
    case .in30s: "30s"
    case .in40s: "40s"
    case .in50sOrGreater: "50s or greater"
    case .under20: "Under 20"
    }
  }
}

extension HumanGender {
  fileprivate var generableDescription: String {
    switch self {
    case .male: "Male"
    case .female: "Female"
    case .nonBinary: "Non-binary"
    }
  }
}

extension HumanActivityLevel {
  fileprivate var generableDescription: String {
    switch self {
    case .active: "Active"
    case .sedentary: "Sedentary"
    case .somewhatActive: "Somewhat Active"
    case .veryActive: "Very Active"
    }
  }
}

extension HumanWorkoutFrequency {
  fileprivate var generableDescription: String {
    switch self {
    case .everyDay: "Every day"
    case .everyOtherDay: "Every other day"
    case .mostDays: "Most days"
    case .noDays: "No days"
    case .onceOrTwicePerWeek: "Once or twice per week"
    }
  }
}
