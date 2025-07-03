import SwiftUI

// MARK: - HumanAgeRange

public enum HumanAgeRange: String, Hashable, Sendable, CaseIterable {
  case under20
  case in20s
  case in30s
  case in40s
  case in50sOrGreater
}

// MARK: - LocalizedStringKey

extension HumanAgeRange {
  public var localizedString: LocalizedStringKey {
    switch self {
    case .under20: "Under 20"
    case .in20s: "20s"
    case .in30s: "30s"
    case .in40s: "40s"
    case .in50sOrGreater: "50s or greater"
    }
  }
}
