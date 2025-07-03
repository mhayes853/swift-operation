import SwiftUI

// MARK: - HumanWorkoutFrequency

public enum HumanWorkoutFrequency: String, Hashable, Sendable, CaseIterable {
  case noDays
  case onceOrTwicePerWeek
  case everyOtherDay
  case mostDays
  case everyDay
}

// MARK: - Localized String

extension HumanWorkoutFrequency {
  public var localizedString: LocalizedStringKey {
    switch self {
    case .noDays: "Never"
    case .onceOrTwicePerWeek: "1-2 Times per Week"
    case .everyOtherDay: "Every Other Day"
    case .mostDays: "Most Days"
    case .everyDay: "Every Day"
    }
  }
}
