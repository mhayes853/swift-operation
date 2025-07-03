import SwiftUI

// MARK: - HumanActivityLevel

public enum HumanActivityLevel: String, Hashable, Sendable, CaseIterable {
  case sedentary
  case somewhatActive
  case active
  case veryActive
}

extension HumanActivityLevel {
  public var localizedString: LocalizedStringKey {
    switch self {
    case .sedentary: "Sedentary"
    case .somewhatActive: "Somewhat Active"
    case .active: "Active"
    case .veryActive: "Very Active"
    }
  }
}
